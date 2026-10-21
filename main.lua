--=========================================================--
--      MInh HUB-BLOXFRUITS | BLOX FRUITS (MINH HUB MENU)       --
--=========================================================--
-- =========================================================
-- ỔN ĐỊNH: chống chạy trùng + vòng lặp tự hồi phục khi gặp lỗi
--  * Chạy script lần 2 khi bản cũ còn sống -> bỏ qua (tránh 2 vòng farm cùng lúc, spam remote).
--    Muốn ép chạy lại: đặt _G.MinhHubForce = true trước khi execute (hoặc rejoin).
--  * _G.MHSpawn = task.spawn có bắt lỗi: vòng lặp bị lỗi nil/remote sẽ tự chạy lại sau 2s
--    (tối đa 5 lần liên tiếp; chạy ổn định >10s thì đếm lại từ đầu) thay vì chết im lặng.
-- =========================================================
if _G.MinhHubAlive and (tick() - _G.MinhHubAlive) < 4 and not _G.MinhHubForce then
    warn("[Minh Hub] Script đang chạy rồi — bỏ qua lần execute thứ 2 (đặt _G.MinhHubForce=true để ép chạy lại).")
    do return end
end
_G.MinhHubForce = nil
_G.MHGen = (_G.MHGen or 0) + 1
do
    local gen = _G.MHGen
    local startT = tick()
    _G.MinhHubAlive = tick()
    local realSpawn = task.spawn
    local realWait = task.wait
    realSpawn(function()
        while _G.MHGen == gen do
            -- trước khi load xong: giữ "sống" tối đa 60s (nếu script chết giữa chừng thì cho phép chạy lại)
            if _G.MinhHubReady or (tick() - startT) < 60 then _G.MinhHubAlive = tick() end
            realWait(1)
        end
    end)
    _G.MHSpawn = function(fn, ...)
        local args = table.pack(...)
        return realSpawn(function()
            local fails = 0
            while _G.MHGen == gen do
                local t0 = tick()
                local ok, err = pcall(fn, table.unpack(args, 1, args.n))
                if ok then return end
                if tick() - t0 > 10 then fails = 0 end
                fails = fails + 1
                warn("[Minh Hub] Luồng bị lỗi (" .. fails .. "/5): " .. tostring(err))
                if fails >= 5 then return end
                realWait(2)
            end
        end)
    end
end

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")


-- =========================================================
-- MÀN HÌNH LOADING: hiển thị tiến trình tải script (thanh % + bước đang tải + thời gian)
--  * _G.MinhHubLoad(phần_trăm, "nội dung")  : cập nhật tiến trình
--  * _G.MinhHubLoadDone()                   : báo tải xong -> hiện 100% rồi mờ dần và đóng
--  * Tự đóng sau 40 giây nếu script bị lỗi giữa chừng (tránh kẹt màn hình)
-- =========================================================
_G.MinhHubReady = false
_G.MinhHubGreeted = false
_G.MinhHubLoad, _G.MinhHubLoadDone = nil, nil
do
    local okL = pcall(function()
        local Real = game:GetService("TweenService")
        local lp = Players.LocalPlayer
        local parent
        local okH, hui = pcall(function() return gethui and gethui() end)
        if okH and hui then parent = hui end
        if not parent then
            local okC, cg = pcall(function() return game:GetService("CoreGui") end)
            if okC and cg then parent = cg end
        end
        if not parent and lp then parent = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10) end
        if not parent then return end

        pcall(function()
            local old = parent:FindFirstChild("MinhHubLoading")
            if old then old:Destroy() end
        end)

        -- Cùng bảng màu & kiểu dáng với menu chính; chữ to, tương phản cao cho dễ đọc
        local ACCENT  = Color3.fromRGB(64, 140, 255)
        local ACCENT_L = Color3.fromRGB(120, 180, 255)
        local BG      = Color3.fromRGB(22, 24, 30)
        local SIDEBAR = Color3.fromRGB(14, 15, 19)
        local CARD    = Color3.fromRGB(44, 46, 54)
        local BORDER  = Color3.fromRGB(72, 76, 88)
        local MUTED   = Color3.fromRGB(150, 155, 172)
        local WHITE   = Color3.fromRGB(240, 242, 250)

        local gui = Instance.new("ScreenGui")
        gui.Name = "MinhHubLoading"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.DisplayOrder = 1000000
        pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
        gui.Parent = parent

        local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o return c end
        local function gradient(o, c0, c1, rot)
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new(c0, c1)
            g.Rotation = rot or 0
            g.Parent = o
            return g
        end

        -- ===== GIAO DIỆN LOADING KIỂU CÔNG NGHỆ (HUD / terminal) =====
        local CY = Color3.fromRGB(70, 210, 255)
        local MONO = Enum.Font.Code
        local CW, CH = 560, 340

        local dim = Instance.new("Frame")
        dim.Size = UDim2.new(1, 0, 1, 0)
        dim.BackgroundColor3 = Color3.fromRGB(3, 5, 10)
        dim.BackgroundTransparency = 0.15
        dim.BorderSizePixel = 0
        dim.Parent = gui

        local blur
        pcall(function()
            blur = Instance.new("BlurEffect")
            blur.Name = "MinhHubLoadingBlur"
            blur.Size = 0
            blur.Parent = game:GetService("Lighting")
            Real:Create(blur, TweenInfo.new(0.6), {Size = 16}):Play()
        end)

        local particles = {}
        local prng = Random.new(os.time())
        for i = 1, 20 do
            local pf = Instance.new("Frame")
            pf.Size = UDim2.new(0, 2, 0, prng:NextInteger(6, 16))
            pf.BackgroundColor3 = CY
            pf.BackgroundTransparency = prng:NextNumber(0.7, 0.92)
            pf.BorderSizePixel = 0
            pf.Parent = gui
            particles[i] = {f = pf, x = prng:NextNumber(), y = prng:NextNumber(), v = prng:NextNumber(0.04, 0.12), sw = 0}
        end

        local glowLayers = {}
        for i = 1, 4 do
            local gl = Instance.new("Frame")
            gl.AnchorPoint = Vector2.new(0.5, 0.5)
            gl.Position = UDim2.new(0.5, 0, 0.5, 0)
            gl.Size = UDim2.new(0, CW + i * 16, 0, CH + i * 16)
            gl.BackgroundColor3 = CY
            gl.BackgroundTransparency = 0.93 + i * 0.015
            gl.BorderSizePixel = 0
            gl.Parent = gui
            corner(gl, 6 + i * 6)
            glowLayers[i] = gl
        end

        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, CW, 0, CH)
        card.AnchorPoint = Vector2.new(0.5, 0.5)
        card.Position = UDim2.new(0.5, 0, 0.5, 0)
        card.BackgroundColor3 = Color3.fromRGB(6, 10, 18)
        card.BackgroundTransparency = 0.04
        card.BorderSizePixel = 0
        card.ClipsDescendants = true
        card.Parent = gui
        corner(card, 6)
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Thickness = 1.2
        stroke.Parent = card
        local strokeGrad = gradient(stroke, CY, Color3.fromRGB(30, 50, 80), 45)
        local cardScale = Instance.new("UIScale")
        cardScale.Scale = 0.92
        cardScale.Parent = card

        local function label(parentObj, txt, size, font, color, pos, sz, align)
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency = 1
            l.Text = txt
            l.TextSize = size
            l.Font = font
            l.TextColor3 = color
            l.Position = pos
            l.Size = sz
            l.TextXAlignment = align or Enum.TextXAlignment.Left
            l.Parent = parentObj
            return l
        end
        local function rect(parentObj, x, y, w, h, color, tr)
            local f = Instance.new("Frame")
            f.Size = UDim2.new(0, w, 0, h)
            f.Position = UDim2.new(0, x, 0, y)
            f.BackgroundColor3 = color
            f.BackgroundTransparency = tr or 0
            f.BorderSizePixel = 0
            f.Parent = parentObj
            return f
        end
        local RIGHT = Enum.TextXAlignment.Right

        -- lưới nền mờ
        for gx = 0, CW, 28 do rect(card, gx, 0, 1, CH, CY, 0.95) end
        for gy = 0, CH, 28 do rect(card, 0, gy, CW, 1, CY, 0.95) end
        -- tia quét chạy dọc
        local scan = Instance.new("Frame")
        scan.Size = UDim2.new(1, 0, 0, 60)
        scan.Position = UDim2.new(0, 0, 0, -60)
        scan.BackgroundColor3 = CY
        scan.BorderSizePixel = 0
        scan.Parent = card
        do
            local g = Instance.new("UIGradient")
            g.Rotation = 90
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.85, 0.93), NumberSequenceKeypoint.new(1, 0.7)})
            g.Parent = scan
        end

        -- 4 góc khung (bracket)
        local function bracket(cx, cy, dx, dy)
            local x0 = cx == 0 and 8 or CW - 8
            local y0 = cy == 0 and 8 or CH - 8
            local hx = dx == 1 and x0 or x0 - 22
            local vy = dy == 1 and y0 or y0 - 22
            rect(card, hx, y0 - (dy == -1 and 2 or 0), 22, 2, CY, 0.05)
            rect(card, x0 - (dx == -1 and 2 or 0), vy, 2, 22, CY, 0.05)
        end
        bracket(0, 0, 1, 1) bracket(1, 0, -1, 1) bracket(0, 1, 1, -1) bracket(1, 1, -1, -1)

        -- thanh trạng thái trên cùng
        local dot = rect(card, 20, 16, 7, 7, CY, 0)
        corner(dot, 4)
        label(card, "MINH_HUB // BLOX_FRUITS // BOOT", 11, MONO, CY, UDim2.new(0, 34, 0, 10), UDim2.new(0, 300, 0, 18))
        local timeL = label(card, "T+0.0s", 11, MONO, MUTED, UDim2.new(1, -120, 0, 10), UDim2.new(0, 100, 0, 18), RIGHT)
        rect(card, 16, 34, CW - 32, 1, CY, 0.75)

        -- lõi "reactor": 3 vòng xoay ngược chiều + chữ M
        local RX, RY = 92, 112
        local rings, ringSpeed = {}, {160, -240, 340}
        for i, r in ipairs({112, 86, 60}) do
            local rf = Instance.new("Frame")
            rf.AnchorPoint = Vector2.new(0.5, 0.5)
            rf.Position = UDim2.new(0, RX, 0, RY)
            rf.Size = UDim2.new(0, r, 0, r)
            rf.BackgroundTransparency = 1
            rf.Parent = card
            corner(rf, r // 2)
            local rs = Instance.new("UIStroke")
            rs.Color = Color3.new(1, 1, 1)
            rs.Thickness = i == 1 and 1.5 or 2.2
            rs.Parent = rf
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new(i == 2 and ACCENT or CY)
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.3, 1),
                NumberSequenceKeypoint.new(0.34, 0.05),
                NumberSequenceKeypoint.new(0.62, 0.05),
                NumberSequenceKeypoint.new(0.66, 1),
                NumberSequenceKeypoint.new(1, 1),
            })
            g.Parent = rs
            rings[i] = g
        end
        local core = Instance.new("Frame")
        core.AnchorPoint = Vector2.new(0.5, 0.5)
        core.Position = UDim2.new(0, RX, 0, RY)
        core.Size = UDim2.new(0, 40, 0, 40)
        core.BackgroundColor3 = Color3.fromRGB(10, 18, 32)
        core.BorderSizePixel = 0
        core.Parent = card
        corner(core, 20)
        local coreStroke = Instance.new("UIStroke")
        coreStroke.Color = CY
        coreStroke.Thickness = 1.5
        coreStroke.Parent = core
        label(core, "M", 22, Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Enum.TextXAlignment.Center)

        -- tiêu đề + hiệu ứng glitch
        local TX = 176
        local ghostC = label(card, "MINH HUB", 36, Enum.Font.GothamBlack, CY, UDim2.new(0, TX, 0, 56), UDim2.new(0, 360, 0, 42))
        local ghostR = label(card, "MINH HUB", 36, Enum.Font.GothamBlack, Color3.fromRGB(255, 70, 110), UDim2.new(0, TX, 0, 56), UDim2.new(0, 360, 0, 42))
        ghostC.TextTransparency = 1
        ghostR.TextTransparency = 1
        local titleL = label(card, "MINH HUB", 36, Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.new(0, TX, 0, 56), UDim2.new(0, 360, 0, 42))
        gradient(titleL, Color3.new(1, 1, 1), Color3.fromRGB(150, 215, 255), 90)
        label(card, "// PREMIUM SCRIPT  ·  BLOX FRUITS", 12, MONO, CY, UDim2.new(0, TX, 0, 100), UDim2.new(0, 360, 0, 18))
        local dispName = "bạn"
        pcall(function() dispName = lp.DisplayName ~= "" and lp.DisplayName or lp.Name end)
        local welcomeL = label(card, "Xin chào, " .. dispName .. "! Đang chuẩn bị script...", 12, Enum.Font.Gotham, MUTED,
            UDim2.new(0, TX, 0, 122), UDim2.new(0, CW - TX - 24, 0, 18))
        welcomeL.TextTruncate = Enum.TextTruncate.AtEnd
        local sysL = label(card, "SYS 0x000000  |  NET OK  |  UI SYNC", 11, MONO, Color3.fromRGB(90, 130, 160),
            UDim2.new(0, TX, 0, 144), UDim2.new(0, CW - TX - 24, 0, 16))

        -- khung terminal: 2 dòng cũ (mờ) + dòng hiện tại + phần trăm lớn
        rect(card, 16, 172, CW - 32, 1, CY, 0.8)
        local logOld2 = label(card, "", 12, MONO, Color3.fromRGB(70, 100, 125), UDim2.new(0, 28, 0, 178), UDim2.new(1, -190, 0, 16))
        local logOld1 = label(card, "", 12, MONO, Color3.fromRGB(110, 150, 180), UDim2.new(0, 28, 0, 194), UDim2.new(1, -190, 0, 16))
        label(card, ">", 12, MONO, CY, UDim2.new(0, 28, 0, 210), UDim2.new(0, 12, 0, 16))
        local step = label(card, "Starting...", 12, MONO, WHITE, UDim2.new(0, 42, 0, 210), UDim2.new(1, -204, 0, 16))
        logOld2.TextTruncate = Enum.TextTruncate.AtEnd
        logOld1.TextTruncate = Enum.TextTruncate.AtEnd
        step.TextTruncate = Enum.TextTruncate.AtEnd
        local lastStep = "Starting..."
        step:GetPropertyChangedSignal("Text"):Connect(function()
            if step.Text == lastStep then return end
            logOld2.Text = logOld1.Text
            logOld1.Text = "✓ " .. lastStep
            lastStep = step.Text
        end)
        local pctL = label(card, "0%", 34, MONO, Color3.new(1, 1, 1), UDim2.new(1, -170, 0, 180), UDim2.new(0, 142, 0, 44), RIGHT)
        pctL.Font = Enum.Font.GothamBlack
        gradient(pctL, Color3.new(1, 1, 1), CY, 90)

        -- thanh tiến trình dạng ô (segmented)
        local SEG = 40
        local segHolder = Instance.new("Frame")
        segHolder.Position = UDim2.new(0, 28, 0, 238)
        segHolder.Size = UDim2.new(1, -56, 0, 12)
        segHolder.BackgroundTransparency = 1
        segHolder.Parent = card
        local segs = {}
        for i = 1, SEG do
            local sf = Instance.new("Frame")
            sf.Position = UDim2.new((i - 1) / SEG, 0, 0, 0)
            sf.Size = UDim2.new(1 / SEG, -3, 1, 0)
            sf.BackgroundColor3 = Color3.fromRGB(24, 38, 56)
            sf.BorderSizePixel = 0
            sf.Parent = segHolder
            segs[i] = {f = sf, lit = false}
        end

        -- 4 chặng
        local stages = {
            {"01 HỆ THỐNG", 20}, {"02 DỮ LIỆU", 45}, {"03 GIAO DIỆN", 75}, {"04 HOÀN TẤT", 100},
        }
        local chips = {}
        local colW = (CW - 56) / 4
        for i, st in ipairs(stages) do
            local chip = Instance.new("Frame")
            chip.BackgroundTransparency = 1
            chip.Position = UDim2.new(0, 28 + (i - 1) * colW, 0, 258)
            chip.Size = UDim2.new(0, colW, 0, 20)
            chip.Parent = card
            local cd = rect(chip, 0, 7, 6, 6, MUTED, 0)
            local cl = label(chip, st[1], 11, MONO, MUTED, UDim2.new(0, 12, 0, 0), UDim2.new(1, -12, 1, 0))
            chips[i] = {chip = chip, dot = cd, lbl = cl, at = st[2], on = false}
        end

        rect(card, 16, 288, CW - 32, 1, CY, 0.8)
        local hintL = label(card, "Menu sẽ tự mở khi tải xong", 11, Enum.Font.Gotham, MUTED,
            UDim2.new(0, 28, 1, -42), UDim2.new(1, -56, 0, 18), Enum.TextXAlignment.Center)
        local TIPS = {
            "💡 Menu sẽ tự mở khi tải xong",
            "💡 Dùng Auto Farm Chest khi rảnh để gom Beli và rương",
            "💡 Nhấn nút Minh Hub để ẩn/hiện menu bất cứ lúc nào",
        }

        local t0 = os.clock()
        local target, shown, closed = 0, 0, false

        pcall(function()
            Real:Create(cardScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end)

        local conn
        conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
            if closed then return end
            local t = os.clock() - t0
            shown = shown + (target - shown) * math.min(1, dt * 2.5)
            if target - shown < 0.3 then shown = target end
            local frac = math.clamp(shown / 100, 0, 1)
            pctL.Text = string.format("%d%%", math.floor(shown + 0.5))
            timeL.Text = string.format("T+%.1fs", t)
            if not _G.MinhHubGreeted then hintL.Text = TIPS[(math.floor(t / 2.2) % #TIPS) + 1] end
            strokeGrad.Rotation = 45 + (t * 50) % 360
            dot.BackgroundTransparency = 0.5 - 0.5 * math.sin(t * 6)
            for i, g in ipairs(rings) do g.Rotation = (t * ringSpeed[i]) % 360 end
            for gi, gl in ipairs(glowLayers) do
                gl.BackgroundTransparency = 0.93 + gi * 0.015 + 0.012 * math.sin(t * 2.2)
            end
            coreStroke.Thickness = 1.5 + 0.8 * (0.5 + 0.5 * math.sin(t * 4))
            scan.Position = UDim2.new(0, 0, 0, -60 + ((t % 2.8) / 2.8) * (CH + 60))
            -- glitch tiêu đề thỉnh thoảng
            local gOn = (t % 3.1) < 0.12
            local off = gOn and prng:NextInteger(2, 4) or 0
            ghostC.TextTransparency = gOn and 0.45 or 1
            ghostR.TextTransparency = gOn and 0.55 or 1
            ghostC.Position = UDim2.new(0, TX - off, 0, 56)
            ghostR.Position = UDim2.new(0, TX + off, 0, 56 + (gOn and 1 or 0))
            -- dòng đọc số liệu giả lập
            if math.floor(t * 8) ~= math.floor((t - dt) * 8) then
                sysL.Text = string.format("SYS 0x%06X  |  NET OK  |  UI SYNC", prng:NextInteger(0, 0xFFFFFF))
            end
            -- thanh ô
            local litN = math.floor(frac * SEG + 0.5)
            for i, s in ipairs(segs) do
                local on = i <= litN
                if on ~= s.lit then
                    s.lit = on
                    s.f.BackgroundColor3 = on and CY or Color3.fromRGB(24, 38, 56)
                end
                if on and i == litN and litN < SEG then
                    s.f.BackgroundColor3 = Color3.fromRGB(255, 255, 255):Lerp(CY, 0.5 + 0.5 * math.sin(t * 12))
                    s.lit = nil
                end
            end
            for _, c in ipairs(chips) do
                local on = shown >= c.at - 0.5
                if on ~= c.on then
                    c.on = on
                    local ti = TweenInfo.new(0.25)
                    Real:Create(c.dot, ti, {BackgroundColor3 = on and CY or MUTED}):Play()
                    Real:Create(c.lbl, ti, {TextColor3 = on and Color3.new(1, 1, 1) or MUTED}):Play()
                end
            end
            for _, pt in ipairs(particles) do
                pt.y = pt.y - pt.v * dt
                if pt.y < -0.05 then pt.y = 1.05 pt.x = prng:NextNumber() end
                pt.f.Position = UDim2.new(pt.x, 0, pt.y, 0)
            end
        end)

        -- Thông báo chào mừng (tự vẽ, không dùng thông báo mặc định của Roblox) trượt vào góc phải dưới
        local function showWelcomeToast()
            pcall(function()
                local tg = Instance.new("ScreenGui")
                tg.Name = "MinhHubWelcome"
                tg.ResetOnSpawn = false
                tg.IgnoreGuiInset = true
                tg.DisplayOrder = 1000001
                tg.Parent = parent
                local W, H = 330, 84
                local f = Instance.new("Frame")
                f.AnchorPoint = Vector2.new(1, 1)
                f.Size = UDim2.new(0, W, 0, H)
                f.Position = UDim2.new(1, W + 40, 1, -28)   -- bắt đầu ngoài màn hình bên phải
                f.BackgroundColor3 = Color3.new(1, 1, 1)
                f.BorderSizePixel = 0
                f.ClipsDescendants = true
                f.Parent = tg
                corner(f, 14)
                gradient(f, Color3.fromRGB(38, 44, 66), Color3.fromRGB(16, 17, 24), 60)
                local fs = Instance.new("UIStroke")
                fs.Color = Color3.new(1, 1, 1)
                fs.Thickness = 1.6
                fs.Parent = f
                gradient(fs, ACCENT_L, Color3.fromRGB(60, 64, 80), 60)

                -- vạch màu bên trái
                local bar = Instance.new("Frame")
                bar.Size = UDim2.new(0, 4, 1, 0)
                bar.BackgroundColor3 = Color3.new(1, 1, 1)
                bar.BorderSizePixel = 0
                bar.Parent = f
                gradient(bar, ACCENT_L, Color3.fromRGB(44, 110, 230), 90)

                -- logo tròn
                local lg = Instance.new("Frame")
                lg.Position = UDim2.new(0, 18, 0.5, -24)
                lg.Size = UDim2.new(0, 48, 0, 48)
                lg.BackgroundColor3 = SIDEBAR
                lg.BorderSizePixel = 0
                lg.Parent = f
                corner(lg, 24)
                local lgs = Instance.new("UIStroke")
                lgs.Color = ACCENT
                lgs.Thickness = 2
                lgs.Parent = lg
                label(lg, "M", 24, Enum.Font.GothamBlack, ACCENT_L, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Enum.TextXAlignment.Center)

                label(f, "Chúc anh em chơi vui vẻ! 🎉", 16, Enum.Font.GothamBold, Color3.new(1, 1, 1),
                    UDim2.new(0, 80, 0, 14), UDim2.new(1, -92, 0, 22))
                local sub = label(f, "Minh Hub đã sẵn sàng • " .. dispName, 12, Enum.Font.Gotham, ACCENT_L,
                    UDim2.new(0, 80, 0, 38), UDim2.new(1, -92, 0, 18))
                sub.TextTruncate = Enum.TextTruncate.AtEnd

                -- thanh đếm ngược ở đáy
                local cd = Instance.new("Frame")
                cd.AnchorPoint = Vector2.new(0, 1)
                cd.Position = UDim2.new(0, 0, 1, 0)
                cd.Size = UDim2.new(1, 0, 0, 3)
                cd.BackgroundColor3 = Color3.new(1, 1, 1)
                cd.BorderSizePixel = 0
                cd.Parent = f
                gradient(cd, Color3.fromRGB(44, 110, 230), ACCENT_L, 0)

                Real:Create(f, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    {Position = UDim2.new(1, -24, 1, -28)}):Play()
                Real:Create(cd, TweenInfo.new(5, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)}):Play()
                task.delay(5.2, function()
                    pcall(function()
                        Real:Create(f, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                            {Position = UDim2.new(1, W + 40, 1, -28)}):Play()
                        task.delay(0.6, function() pcall(function() tg:Destroy() end) end)
                    end)
                end)
            end)
        end

        local function close()
            if closed then return end
            closed = true
            showWelcomeToast()
            _G.MinhHubReady = true
            pcall(function() if _G.MinhHubMenuGui then _G.MinhHubMenuGui.Enabled = true end end)  -- hiện menu khi loading đóng
            pcall(function() if conn then conn:Disconnect() end end)
            pcall(function()
                if blur then
                    Real:Create(blur, TweenInfo.new(0.5), {Size = 0}):Play()
                    task.delay(0.6, function() pcall(function() blur:Destroy() end) end)
                end
            end)
            pcall(function()
                local ti = TweenInfo.new(0.5)
                Real:Create(cardScale, ti, {Scale = 0.94}):Play()
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("TextLabel") then Real:Create(d, ti, {TextTransparency = 1}):Play()
                    elseif d:IsA("Frame") then Real:Create(d, ti, {BackgroundTransparency = 1}):Play()
                    elseif d:IsA("UIStroke") then Real:Create(d, ti, {Transparency = 1}):Play() end
                end
            end)
            task.delay(0.6, function() pcall(function() gui:Destroy() end) end)
        end

        -- Tải từ từ: mỗi mốc tạm dừng LOAD_STEP_DELAY giây (chỉnh số này để nhanh/chậm hơn, 0 = không chờ)
        local LOAD_STEP_DELAY = 0.45
        _G.MinhHubLoad = function(pct, text)
            if closed then return end
            if type(pct) == "number" and pct > target then target = math.min(pct, 100) end
            if text then step.Text = tostring(text) end
            if LOAD_STEP_DELAY > 0 then task.wait(LOAD_STEP_DELAY) end
        end
        _G.MinhHubLoadDone = function()
            if closed then return end
            target = 100
            _G.MinhHubGreeted = true
            step.Text = "Hoàn tất!"
            step.TextColor3 = ACCENT_L
            hintL.Text = "🎉 Chúc anh em chơi vui vẻ!"
            hintL.TextColor3 = Color3.new(1, 1, 1)
            hintL.Font = Enum.Font.GothamBold
            hintL.TextSize = 14
            welcomeL.Text = "Tải xong, mở menu..."
            task.delay(1.6, close)
        end

        -- phòng khi script lỗi giữa chừng: tự đóng, không kẹt màn hình
        task.delay(40, close)
    end)
    if not okL or not _G.MinhHubLoadDone then
        -- không tạo được màn hình loading: bỏ qua loading, vẫn hiện menu bình thường
        _G.MinhHubLoad = function() end
        _G.MinhHubLoadDone = function()
            _G.MinhHubReady = true
            pcall(function() if _G.MinhHubMenuGui then _G.MinhHubMenuGui.Enabled = true end end)
        end
    end
end
_G.MinhHubLoad(5, "Loading stable flight system...")
-- =========================================================
-- BỘ BAY ỔN ĐỊNH (thay thế Tween CFrame của HumanoidRootPart)
-- Mọi chỗ gọi TweenService:Create(HumanoidRootPart, ..., {CFrame = ...}) giờ đều đi qua bộ bay này:
--  * Bay theo từng frame (Heartbeat), tốc độ ĐỀU = khoảng cách / thời gian (= flySpeed)
--  * Triệt tiêu vận tốc + tắt va chạm mỗi frame -> không rơi, không kẹt tường
--  * Server kéo nhân vật lệch > 40 studs thì lấy vị trí thật làm gốc rồi bay tiếp
--  * Tween UI (GUI) vẫn dùng TweenService thật như cũ
-- =========================================================
_G.__FlyN = 0
local TweenService
do
    local Real = game:GetService("TweenService")

    local function newFlyTween(hrp, info, props)
        local goalCF = props.CFrame
        local self = { PlaybackState = Enum.PlaybackState.Begin }
        local handlers = {}
        local conn

        self.Completed = {
            Connect = function(_, fn)
                table.insert(handlers, fn)
                return { Disconnect = function() end }
            end,
        }

        local function finish(state)
            if conn then
                conn:Disconnect()
                conn = nil
                _G.__FlyN = math.max(0, (_G.__FlyN or 0) - 1)
            end
            self.PlaybackState = state
            for _, fn in ipairs(handlers) do _G.MHSpawn(fn, state) end
        end

        function self:Cancel()
            if self.PlaybackState == Enum.PlaybackState.Playing then
                finish(Enum.PlaybackState.Cancelled)
            end
        end
        function self:Pause() self:Cancel() end
        function self:Destroy() self:Cancel() end

        function self:Play()
            if self.PlaybackState == Enum.PlaybackState.Playing then return end
            self.PlaybackState = Enum.PlaybackState.Playing
            _G.__FlyN = (_G.__FlyN or 0) + 1

            local pos = hrp.Position
            local dist0 = (goalCF.Position - pos).Magnitude
            local speed = math.clamp(dist0 / math.max(info.Time, 0.05), 40, 600)

            conn = RunService.Heartbeat:Connect(function(dt)
                if not hrp.Parent then finish(Enum.PlaybackState.Cancelled) return end
                dt = math.min(dt, 0.1)

                local actual = hrp.Position
                if (actual - pos).Magnitude > 40 then pos = actual end

                local delta = goalCF.Position - pos
                local d = delta.Magnitude
                local step = speed * dt

                if d <= step then
                    hrp.CFrame = goalCF
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    finish(Enum.PlaybackState.Completed)
                    return
                end

                pos = pos + delta.Unit * step
                hrp.CFrame = (goalCF - goalCF.Position) + pos
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero

                local ch = hrp.Parent
                if ch then
                    for _, part in ipairs(ch:GetChildren()) do
                        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                    end
                end
            end)
        end

        return self
    end

    TweenService = setmetatable({}, {
        __index = function(_, k)
            if k == "Create" then
                return function(_, inst, info, props)
                    if typeof(inst) == "Instance" and inst.Name == "HumanoidRootPart" and inst:IsA("BasePart")
                        and type(props) == "table" and next(props) == "CFrame" and next(props, "CFrame") == nil then
                        return newFlyTween(inst, info, props)
                    end
                    return Real:Create(inst, info, props)
                end
            end
            local v = Real[k]
            if type(v) == "function" then
                return function(_, ...) return v(Real, ...) end
            end
            return v
        end,
    })
end

-- Dùng pcall để tránh crash nếu executor không hỗ trợ các dịch vụ ảo hóa
local okVIM, VirtualInputManager = pcall(function() return game:GetService("VirtualInputManager") end)
local okVU, VirtualUser          = pcall(function() return game:GetService("VirtualUser") end)

local LocalPlayer = Players.LocalPlayer
_G.MinhHubLoad(10, "Loading player information...")
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- =========================================================
-- LƯU CÀI ĐẶT (bền qua server hop): _G bị xoá khi đổi server nên cài đặt phe /
-- Cài đặt chọn phe được ghi vào file MinhHub_Settings.json (writefile/readfile).
-- Mặc định: TỰ ĐỘNG VÀO PHE = BẬT (Hải tặc).
-- =========================================================
do
    local HttpService = game:GetService("HttpService")
    local SETTINGS_FILE = "MinhHub_Settings.json"
    local data = {}
    pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" and isfile(SETTINGS_FILE) then
            local decoded = HttpService:JSONDecode(readfile(SETTINGS_FILE))
            if type(decoded) == "table" then data = decoded end
        end
    end)
    local store = {data = data}
    function store.save()
        pcall(function()
            if type(writefile) == "function" then
                writefile(SETTINGS_FILE, HttpService:JSONEncode(store.data))
            end
        end)
    end
    _G.MinhHubSettings = store

    -- File thắng _G (vì _G ở server mới chỉ có giá trị cũ do bootstrap truyền sang)
    if data.autoTeam ~= nil then _G.MinhHubAutoSelectTeam = (data.autoTeam == true) end
    if data.team == "Marines" or data.team == "Pirates" then _G.MinhHubSelectedTeam = data.team end
    -- Mặc định lần đầu chạy: bật tự động chọn phe
    if _G.MinhHubAutoSelectTeam == nil then _G.MinhHubAutoSelectTeam = true end
    if _G.MinhHubSelectedTeam == nil then _G.MinhHubSelectedTeam = "Pirates" end
end

-- =========================================================

-- HÀM LẤY LEVEL AN TOÀN
local function getLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    if data and data:FindFirstChild("Level") then
        return data.Level.Value
    end
    return 1
end

-- KIỂM TRA & XÁC ĐỊNH SEA (WORLD 1, 2, 3) + AUTO FALLBACK
local placeId = game.PlaceId
-- Hỗ trợ cả PlaceId Sea cũ và các PlaceId phụ do người dùng cung cấp.
local World1  = (placeId == 2753915549 or placeId == 85211729168715)
local World2  = (placeId == 4442272183 or placeId == 79091703265657)
local World3  = (placeId == 7449423635 or placeId == 100117331123089)

if not (World1 or World2 or World3) then
    local lvl = getLevel()
    if lvl < 700 then
        World1 = true
    elseif lvl < 1500 then
        World2 = true
    else
        World3 = true
    end
end

-- XỬ LÝ RESET TRẠNG THÁI KHI NHÂN VẬT CHẾT / HỒI SINH
local currentFlyTween = nil
local targetEnemy     = nil
local currentRaidTween = nil
-- CẤU HÌNH & TRẠNG THÁI
local autoAfkEnabled          = true
local autoFarmEnabled         = false
local autoQuestEnabled        = true  -- Tự động nhận Quest khi bật Auto Farm
local autoFarmMaterialEnabled = false
local bringMobsEnabled        = true
local maxBringCount           = 6
local fastAttackEnabled       = true
local maxAttackTargets        = 2     -- số quái Fast Attack đánh cùng lúc
local EH = {
    names = {"Diablo", "Urban", "Deandre"},
    status = "Disabled", lastReply = "-", progress = "?", lastKillAt = 0,
    hasChalice = false, hasFist = false, invAt = 0, invOk = false,
    statusLabel = nil, wasLive = false, questTakenAt = 0, cakeLeft = nil, startedAt = 0, rows = nil, hoverBoss = nil, holdPos = nil, hasQuest = false, flyBoss = nil,
}
local TY = {
    status = "Disabled", phase = "farm", kills = 0, sideKills = 0, side = 1, phaseAt = 0,
    vaseTry = {}, vases = {}, vaseAt = 0, hover = nil, goal = nil, hold = nil, curMob = nil,
    bossSeen = false, eyeLit = nil, eyeTotal = nil,
}
local FA = {
    playerEnabled = true,   -- Fast Attack cả người chơi (kết hợp với quái)
    maxPlayers    = 2,      -- số người chơi đánh cùng lúc (cộng thêm ngoài số quái)
    auto          = true,   -- Tự bật Fast Attack khi bắt đầu farm + tự đánh khi có mục tiêu trong tầm
    wasFarming    = false,
}
local autoHakiEnabled         = true  -- Auto Buso Haki
local autoObservationEnabled  = true  -- Auto Observation Haki / Instinct
local observationState        = { char = nil, on = false, lastTry = 0, tries = 0, attempts = 0, pressedE = false, busy = false }
local ensureObservation       -- khai báo trước để nút bật/tắt trong menu gọi được (định nghĩa ở dưới)
local autoRaceV3Enabled       = true
local autoRaceV4Enabled       = true

-- CẤU HÌNH RANDOM BONES & CẤT TRÁI
local autoRandomBonesEnabled  = false
local autoStoreFruitEnabled   = false
local autoRandomFruitEnabled  = false  -- Auto mua Random Fruit (Cousin)
local autoChestEnabled        = false  -- Auto Farm Chest

-- CẤU HÌNH BAY CAO

-- CẤU HÌNH DI CHUYỂN SUBMERGED ISLAND (SEA 3)
-- Tách riêng trạng thái vào đảo để Auto Level không bị kẹt ở Tiki Outpost.
local SUBMERGED_CENTER = Vector3.new(10000, -2050, 9800)
local SUBMERGED_ENTRY_POS = Vector3.new(10000, -2050, 9800)
local SUBMERGED_Y = -1400 -- mốc xác nhận đã xuống đủ sâu
local SUBMERGED_WORKER_POS = Vector3.new(-16246.041, 38.48, 1376.539) -- tọa độ dự phòng từ bản Auto Travel
local submergedTravelBusy = false
local submergedTravelLast = 0
local submergedTravelAttempts = 0

-- DANH SÁCH & NGUYÊN LIỆU AUTO FARM MATERIAL
local selectedMaterialTarget = ""
local currentMatPointIndex   = 1
local lastPointSwitchTime    = 0

-- BẢNG NGUYÊN LIỆU THEO TỪNG SEA (Sea 1 / Sea 2 / Sea 3)
-- mobs  = tên quái rớt nguyên liệu ở Sea đó (script tự tìm quái theo TÊN, không phụ thuộc toạ độ)
-- spots = toạ độ dự phòng, chỉ dùng khi không tìm thấy điểm hồi sinh quái trong map
local materialData = {
    ["Scrap Metal & Leather"] = {
        [1] = { mobs  = {"Pirate", "Brute"},
                spots = { Vector3.new(-1076.60, 27.30, 3960.73)} },
        [2] = { mobs  = {"Mercenary", "Marine Captain", "Swan Pirate"},
                spots = { Vector3.new(-2448.00, 73.00, -3210.00) } },
        [3] = { mobs  = {"Pirate Millionaire", "Pistol Billionaire"},
                spots = { Vector3.new(-290.00, 43.00, 5583.00) } },
    },
    ["Angel Wing"] = {
        [1] = { mobs  = {"God's Guard", "Shanda", "Royal Squad", "Royal Soldier", "Wysper"},
                spots = { Vector3.new(-4198.00, 1173.98, -366.06) } },
    },
    ["Fish Tail"] = {
        [1] = { mobs  = {"Fishman Warrior", "Fishman Commando"},
                spots = { Vector3.new(61163.85, 11.00, 1819.78) } },
        [3] = { mobs  = {"Fishman Raider", "Fishman Captain"},
                spots = { Vector3.new(-10356.67, 278.79, -8350.42) } },
    },
    ["Magma Ore"] = {
        [1] = { mobs  = {"Military Soldier", "Military Spy"},
                spots = { Vector3.new(-5231.00, 8.00, 8467.00) } },
        [2] = { mobs  = {"Lava Pirate", "Magma Ninja"},
                spots = { Vector3.new(-5091.50, 29.20, -4972.79), Vector3.new(-5787.18, 29.20, -5543.03) } },
    },
    ["Vampire Fang"] = {
        [2] = { mobs  = {"Vampire"},
                spots = { Vector3.new(-6017.76, 6.43, -1320.76) } },
    },
    ["Ectoplasm"] = {
        [2] = {
            -- Các NPC ở Cursed Ship (Sea 2) đều có thể rơi Ectoplasm.
            mobs = {"Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer", "Cursed Captain"},
            -- Điểm dự phòng trong Thuyền Ma nếu EnemySpawns chưa được tải.
            spots = {
                Vector3.new(921.12, 125.98, 33088.33), -- Ship Deckhand
                Vector3.new(919.48, 43.54, 32779.97),  -- Ship Engineer
                Vector3.new(943.85, 129.58, 33444.37), -- Ship Steward
                Vector3.new(1036.02, 181.43, 33315.73), -- Ship Officer
            },
        },
    },
    ["Radioactive Material"] = {
        [2] = { mobs  = {"Factory Staff", "Swan Pirate"},
                spots = { Vector3.new(295.00, 73.00, -56.00), Vector3.new(925.00, 125.00, 3280.00) } },
    },
    ["Mystic Droplet"] = {
        [2] = { mobs  = {"Sea Soldier", "Water Fighter"},
                spots = { Vector3.new(-3451.02, 238.88, -10537.89), Vector3.new(-3347.21, 27.00, -9835.69), Vector3.new(-2686.37, 27.00, -9786.82) } },
    },
    ["Dragon Scale"] = {
        [3] = { mobs  = {"Dragon Crew Warrior", "Dragon Crew Archer"},
                spots = { Vector3.new(5820.68, 1071.01, -71.86) } },
    },
    ["Conjured Cocoa"] = {
        [3] = { mobs  = {"Cocoa Warrior", "Chocolate Bar Battler"},
                spots = { Vector3.new(699.97, 0.50, -12611.47), Vector3.new(-12.14, 0.50, -12245.52) } },
    },
    ["Mini Tusk"] = {
        [3] = { mobs  = {"Mythological Pirate"},
                spots = { Vector3.new(-13571.01, 427.87, -6857.66) } },
    },
    ["Demonic Soul"] = {
        [3] = { mobs  = {"Demonic Soul"},
                spots = { Vector3.new(-9516.00, 142.00, 5535.00) } },
    },
}

-- CẤU HÌNH AUTO RAID & LAW RAID
_G.SelectChip   = "Flame"
_G.AutoBuyChip  = false
_G.StartRaid    = false
_G.Dungeon      = false
_G.AutoLawRaid  = false

-- CẤU HÌNH AUTO PICKUP FRUIT (nhặt Trái Ác Quỷ rơi trên map)
_G.AutoPickupFruit        = false
_G.FruitPickupBusy        = false     -- true khi đang bay đi nhặt (các vòng farm khác tạm dừng)
_G.FruitPickupDebug       = true      -- in log nhặt trái ra console
_G.FruitFlySpeed          = 300       -- tốc độ bay thẳng tới trái (studs/giây)
_G.FruitPickupMaxDistance = math.huge -- chỉ nhặt trái trong bán kính này (studs); mặc định: cả map

-- CẤU HÌNH AUTO FARM PIRATE RAID (hải tặc tấn công Castle on the Sea - chỉ có ở Sea 3)
_G.PirateRaidFarm      = false
_G.PirateRaidBusy      = false   -- true khi đang đánh hải tặc (các vòng farm khác tạm dừng)
_G.PirateRaidStatus    = "Disabled"
_G.PirateRaidRadius    = 900     -- bán kính (studs) quanh Castle on the Sea tính là quái của Pirate Raid
_G.PirateRaidSpeed     = 300     -- tốc độ bay thẳng tới hải tặc (studs/giây)
_G.PirateRaidAutoTravel = true   -- nghe thông báo "Pirates have been spotted..." rồi bay sẵn tới lâu đài
_G.PirateRaidDebug     = true
_G.RaidKillAura = true   -- Kill Aura khi farm Raid ở đảo 4-5
_G.RaidKillAuraIsland = 4  -- từ đảo này trở đi dùng Kill Aura
_G.RaidKillAuraReset = true  -- true: reset (đặt máu = 0 + BreakJoints) quái Raid; false: chỉ gom & đánh

local autoRaidEnabled       = false
local autoBuyChipEnabled    = false
local autoStartRaidEnabled  = false
local selectedRaidChip      = "Flame"

local farmDistanceHeight    = 35
local flySpeed              = 190 -- tốc độ bay mặc định 190 studs/giây
local bringRadius           = 250
local selectedWeapon        = "Melee"
local weaponTypes           = {"Melee", "Sword", "Blox Fruit", "Gun"}
local selectedFarmTarget    = "Auto Level"
local selectedBossTarget    = ""

local toggleUpdateFuncs     = {}

-- HÀM BAY SMOOTH BẰNG TWEENSERVICE (đã sửa: có timeout, không treo vòng lặp)
local function cancelFarmTween()
    if currentFlyTween then pcall(function() currentFlyTween:Cancel() end); currentFlyTween = nil end
end

-- keepGoing (tuỳ chọn): hàm trả về false thì dừng bay NGAY (vd khi người dùng tắt chức năng)
local function stopAllFlying()
    cancelFarmTween()
    if currentRaidTween then pcall(function() currentRaidTween:Cancel() end); currentRaidTween = nil end
    pcall(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)
end

local function flyTo(targetCFrame, speed, keepGoing)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local hrp      = character.HumanoidRootPart
    local spd      = speed or flySpeed or 190
    local distance = (hrp.Position - targetCFrame.Position).Magnitude

    cancelFarmTween() -- tránh 2 tween tranh nhau điều khiển nhân vật
    if currentRaidTween then pcall(function() currentRaidTween:Cancel() end); currentRaidTween = nil end

    if distance > 10 then
        local duration = distance / spd
        local tw = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        currentRaidTween = tw
        tw:Play()
        local t0 = tick()
        -- chờ có giới hạn thời gian thay vì Completed:Wait() (dễ treo vĩnh viễn)
        while tw.PlaybackState == Enum.PlaybackState.Playing and tick() - t0 < duration + 1.5 do
            if keepGoing and not keepGoing() then break end
            task.wait()
        end
        if currentRaidTween == tw then currentRaidTween = nil end
        if tw.PlaybackState == Enum.PlaybackState.Playing then tw:Cancel() end
    else
        hrp.CFrame = targetCFrame
    end
end

-- HÀM TOPOS
-- ANTI-AFK
LocalPlayer.Idled:Connect(function()
    if autoAfkEnabled and okVU and VirtualUser then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)

local HAUNTED_CASTLE_POS    = Vector3.new(-9516, 142, 5535)
local CAKE_ISLAND_POS       = Vector3.new(-2086, 70, -12245)
local CAKE_PRINCE_GATE_POS  = Vector3.new(-2157.34, 70.01, -12406.22)

-- DANH SÁCH BOSS THEO TỪNG SEA (menu chỉ hiện boss của Sea đang đứng)
local currentSeaIndex = World1 and 1 or (World2 and 2 or 3)

local seaBosses = {
    [1] = {
        "Gorilla King", "Chef", "Yeti", "Vice Admiral", "Greybeard", "Warden",
        "Magma Admiral", "Fishman Lord", "Wysper", "Thunder God", "Cyborg", "Saber Expert", "Mob Leader"
    },
    [2] = {
        "Diamond", "Jeremy", "Don Swan", "Smoke Admiral", "Awakened Ice Admiral", "Tide Keeper", "Cursed Captain"
    },
    [3] = {
        "Stone", "Hydra Leader", "Kilo Admiral", "Captain Elephant",
        "Beautiful Pirate", "Longma", "Cake Queen", "Cake Prince",
        "Tyrant of the Skies", "Dough King", "rip_indra", "Soul Reaper"
    },
}

-- Toạ độ DỰ PHÒNG. Script ưu tiên lấy điểm hồi sinh thật trong workspace._WorldOrigin.EnemySpawns,
-- chỉ dùng bảng này khi không tìm thấy.
local bossSpawnLocations = {
    -- Sea 1
    ["Gorilla King"]  = Vector3.new(-1275.58, -4.27, -602.08),
    ["Chef"]          = Vector3.new(-1067.30, 27.30, 3965.59),
    ["Yeti"]          = Vector3.new(1413.50, 97.39, -1570.60),
    ["Vice Admiral"]  = Vector3.new(-4855.60, 25.32, 4293.51),
    ["Greybeard"]     = Vector3.new(-4855.60, 25.32, 4293.51),
    ["Warden"]        = Vector3.new(5582.44, 4.18, 735.90),
    ["Magma Admiral"] = Vector3.new(-5706.93, 77.77, 8759.37),
    ["Fishman Lord"]  = Vector3.new(61352.11, 71.22, 940.53),
    ["Wysper"]        = Vector3.new(-6225.75, 5473.75, 1877.87),
    ["Thunder God"]   = Vector3.new(-7118.07, 5593.60, 321.77),
    ["Cyborg"]        = Vector3.new(6056.19, 76.09, 4780.08),
    ["Saber Expert"]  = Vector3.new(-1508.75, 39.37, 2.60),
    ["Mob Leader"]    = Vector3.new(-2838.58, 4.18, 5331.74),  -- ước lượng, ưu tiên điểm hồi sinh thật
    -- Sea 2
    ["Diamond"]              = Vector3.new(-1576.70, 198.60, -3060.00),
    ["Jeremy"]               = Vector3.new(2316.00, 449.00, 787.00),
    ["Don Swan"]             = Vector3.new(2286.00, 15.00, 863.00),
    ["Smoke Admiral"]        = Vector3.new(-5115.00, 24.00, -5338.00),
    ["Awakened Ice Admiral"] = Vector3.new(6473.00, 297.00, -6944.00),
    ["Tide Keeper"]          = Vector3.new(-3570.00, 123.00, -11555.00),
    -- Boss trong Thuyền Ma (script tự thoát/vào cổng qua Q.enterIfNeeded vì toạ độ nằm trong vùng thuyền)
    ["Cursed Captain"]       = Vector3.new(916.93, 181.09, 33422.00),
    -- Sea 3
    ["Stone"]             = Vector3.new(-1195.76, 105.13, 6916.22),
    ["Hydra Leader"]      = Vector3.new(5820.68, 1071.01, -71.86),
    ["Kilo Admiral"]      = Vector3.new(3060.55, 523.81, -7260.22),
    ["Captain Elephant"]  = Vector3.new(-13567.31, 361.72, -8435.70),
    ["Beautiful Pirate"]  = Vector3.new(5366.19, 22.30, -192.95),
    ["Longma"]            = Vector3.new(-10168.76, 374.80, -9528.21),
    ["Cake Queen"]        = Vector3.new(-710.61, 381.60, -11035.15),
    ["Cake Prince"]       = Vector3.new(-2157.34, 70.01, -12406.22),
    ["Dough King"]        = Vector3.new(-2157.34, 70.01, -12406.22),
    ["rip_indra"]         = Vector3.new(-5312.19, 424.01, -2625.07),
    ["Soul Reaper"]       = Vector3.new(-9520.92, 315.93, 6709.41),
     ["Tyrant of the Skies"]       = Vector3.new(-16356.70, 152.44, 1395.67),
}

-- Boss mặc định = boss đầu tiên của Sea hiện tại (tránh chuỗi rỗng khiến script đánh nhầm mọi quái)
if selectedBossTarget == "" or selectedBossTarget == nil then
    selectedBossTarget = (seaBosses[currentSeaIndex] or {})[1] or "None"
end

local raidChipsList = {
    "Flame", "Ice", "Quake", "Light", "Dark", 
    "Spider", "Magma", "Buddha", "Sand", "Dough", "Phoenix"
}

_G.MinhHubLoad(18, "Loading Auto Quest data...")
-- =========================================================--
--              HỆ THỐNG DỮ LIỆU AUTO QUEST                 --
-- =========================================================--
-- Dữ liệu quest đã được sửa lại đúng tên quest / tên quái / mốc level của game.
-- Mỗi dòng: {level tối thiểu, tên quest, số thứ tự quest, tên quái, vị trí NPC, vị trí quái}
-- (vị trí quái chỉ là dự phòng, script ưu tiên tìm điểm hồi sinh thật trong EnemySpawns)
local GetQuestData, GetQuestMobSpawn
do
    local V = Vector3.new
    local QUESTS = {
        [1] = {
            {1,   "BanditQuest1",   1, "Bandit",              V(1059.37, 15.45, 1550.42),     V(1045.96, 27.00, 1560.82)},
            {10,  "JungleQuest",    1, "Monkey",              V(-1685.68, 50.38, 174.81),     V(-1655.70, 18.39, 238.73)},
            {15,  "JungleQuest",    2, "Gorilla",             V(-1685.68, 50.38, 174.81),     V(-1129.88, 40.46, -525.42)},
            {30,  "BuggyQuest1",    1, "Pirate",              V(-1150.76, 17.61, 3859.29),     V(-1078.98, 27.30, 3962.04)},
            {40,  "BuggyQuest1",    2, "Brute",               V(-1150.76, 17.61, 3859.29),     V(-1053.61, 27.30, 4242.90)},
            {60,  "DesertQuest",    1, "Desert Bandit",       V(863.57, 6.21, 4453.27),       V(928.33, 5.90, 4513.31)},
            {75,  "DesertQuest",    2, "Desert Officer",      V(863.57, 6.21, 4453.27),       V(1561.47, 13.73, 4162.75)},
            {90,  "SnowQuest",      1, "Snow Bandit",         V(1396.68, 78.34, -1312.58),    V(1354.35, 87.27, -1393.95)},
            {100, "SnowQuest",      2, "Snowman",             V(1396.68, 78.34, -1312.58),    V(1148.34, 97.52, -1661.28)},
            {120, "MarineQuest2",   1, "Chief Petty Officer", V(-4701.63, 6.19, 4224.32), V(-4822.64, 4.18, 4098.37)},
            {150, "SkyQuest",       1, "Sky Bandit",          V(-5401.33, 415.73, -694.87),  V(-5118.66, 279.39, -1085.51)},
            {175, "SkyQuest",       2, "Dark Master",         V(-5401.33, 415.73, -694.87),  V(-5310.52, 501.51, -356.85)},
            {190, "PrisonerQuest",  1, "Prisoner",            V(5204.00, 24.55, 737.12),       V(5284.89, 19.55, 509.94)},
            {210, "PrisonerQuest",  2, "Dangerous Prisoner",  V(5204.00, 24.55, 737.12),      V(5286.47, 19.55, 959.17)},
            {250, "ColosseumQuest", 1, "Toga Warrior",        V(-1339.27, 17.48, -2926.53),    V(-1730.26, 12.21, -2715.77)},
            {275, "ColosseumQuest", 2, "Gladiator",           V(-1339.27, 17.48, -2926.53),    V(-1159.36, 12.21, -3222.02)},
            {300, "MagmaQuest",     1, "Military Soldier",    V(-5310.19, 23.47, 8485.85),    V(-5411.16, 11.08, 8454.29)},
            {325, "MagmaQuest",     2, "Military Spy",        V(-5310.19, 23.47, 8485.85),    V(-5952.57, 77.32, 8891.88)},
            {375, "FishmanQuest",   1, "Fishman Warrior",     V(61403.79, 29.94, 1630.02),    V(60833.39, 24.93, 1391.36)},
            {400, "FishmanQuest",   2, "Fishman Commando",    V(61403.79, 29.94, 1630.02),    V(61925.99, 24.93, 1346.67)},
            -- Sea 1 Skylands: tọa độ theo cấu hình Auto Level được cung cấp.
            {450, "SkyExp1Quest",   1, "God's Guard",         V(-4721.88867, 843.874695, -1949.96643), V(-4710.04297, 845.27698, -1927.30798)},
            {475, "SkyExp1Quest",   2, "Shanda",              V(-5954.92, 5474.16, 2087.68), V(-5959.89, 5469.16, 1846.12)},
            {525, "SkyExp2Quest",   1, "Royal Squad",         V(-7028.59, 5596.90, 1353.15), V(-6797.82, 5549.47, 1251.23)},
            {550, "SkyExp2Quest",   2, "Royal Soldier",       V(-7028.59, 5596.90, 1353.15), V(-7089.96, 5540.58, 841.68)},
            {625, "FountainQuest",  1, "Galley Pirate",       V(5260.69, 81.09, 4085.24),     V(5554.44, 71.13, 3822.57)},
            {650, "FountainQuest",  2, "Galley Captain",      V(5260.69, 81.09, 4085.24),     V(5665.51, 71.13, 4975.96)},
        },
        [2] = {
            {700,  "Area1Quest",        1, "Raider",            V(-427.57, 73.31, 1835.87),     V(-728.33, 52.78, 2345.77)},
            {725,  "Area1Quest",        2, "Mercenary",         V(-427.57, 73.31, 1835.87),     V(-1004.32, 80.16, 1424.62)},
            {775,  "Area2Quest",        1, "Swan Pirate",       V(635.61, 73.11, 917.81),       V(1068.66, 137.61, 1322.11)},
            {800,  "Area2Quest",        2, "Factory Staff",     V(635.61, 73.11, 917.81),       V(73.08, 81.86, -27.47)},
            {875,  "MarineQuest3",      1, "Marine Lieutenant", V(-2440.80, 71.71, -3216.07),   V(-2842.69, 72.99, -2901.71)},
            {900,  "MarineQuest3",      2, "Marine Captain",    V(-2440.80, 71.71, -3216.07),   V(-1814.12, 72.99, -3318.82)},
            {950,  "ZombieQuest",       1, "Zombie",            V(-5492.79, 48.51, -793.71),    V(-5622.03, 48.51, -728.75)},
            {1000, "ZombieQuest",       2, "Vampire",           V(-5492.79, 48.51, -793.71),    V(-6030.32, 6.43, -1313.56)},
            {1050, "SnowMountainQuest", 1, "Snow Trooper",      V(607.06, 401.45, -5370.56),    V(535.21, 432.74, -5484.92)},
            {1100, "SnowMountainQuest", 2, "Winter Warrior",    V(607.06, 401.45, -5370.56),    V(1234.45, 456.95, -5174.13)},
            {1125, "IceSideQuest",      1, "Lab Subordinate",   V(-6228.32, 86.85, -4854.02),   V(-5731.82, 81.85, -4421.21)},
            {1150, "IceSideQuest",      2, "Horned Warrior",    V(-6228.32, 86.85, -4854.02),   V(-6411.99, 29.21, -5750.64)},
            {1200, "FireSideQuest",     1, "Magma Ninja",       V(-5400.35, 34.20, -5366.21),   V(-5723.44, 29.20, -5458.18)},
            {1225, "FireSideQuest",     2, "Lava Pirate",       V(-5400.35, 34.20, -5366.21),   V(-5029.98, 29.20, -5008.79)},
            -- Sea 2: Cursed Ship; cổng vào được xử lý tập trung trong Q.enterIfNeeded.
            -- Level 1250: dùng Q.enterIfNeeded để bay tới cổng Graveyard (-6500.94, 87.60, -123.19), vào Thuyền Ma rồi farm Ship Deckhand.
            {1250, "ShipQuest1",        1, "Ship Deckhand",     V(1037.80, 125.09, 32911.60),   V(921.12, 125.98, 33088.33)},
            {1275, "ShipQuest1",        2, "Ship Engineer",     V(1037.80, 125.09, 32911.60),   V(919.48, 43.54, 32779.97)},
            {1300, "ShipQuest2",        1, "Ship Steward",      V(968.80, 125.09, 33244.13),    V(943.85, 129.58, 33444.37)},
            {1325, "ShipQuest2",        2, "Ship Officer",      V(968.80, 125.09, 33244.13),    V(1036.02, 181.43, 33315.73)},
            {1350, "FrostQuest",        1, "Arctic Warrior",    V(5667.66, 26.80, -6486.09),    V(5966.25, 62.97, -6179.38)},
            {1375, "FrostQuest",        2, "Snow Lurker",       V(5667.66, 26.80, -6486.09),    V(5407.07, 69.19, -6880.88)},
            {1450, "ForgottenQuest",    1, "Sea Soldier",       V(-3054.44, 235.54, -10142.82), V(-3028.22, 64.67, -9775.43)},
            {1475, "ForgottenQuest",    2, "Water Fighter",     V(-3054.44, 235.54, -10142.82), V(-3352.90, 285.02, -10534.84)},
        },
        [3] = {
            {1500, "PiratePortQuest",      1, "Pirate Millionaire",    V(-289.62, 43.82, 5579.92),      V(-435.69, 189.80, 5551.08)},
            {1525, "PiratePortQuest",      2, "Pistol Billionaire",    V(-289.62, 43.82, 5579.92),      V(-236.54, 217.47, 6006.08)},
            {1575, "AmazonQuest",          1, "Dragon Crew Warrior",   V(5832.83, 51.69, -1101.52),     V(6141.14, 51.35, -1340.74)},
            {1600, "AmazonQuest",          2, "Dragon Crew Archer",    V(5832.83, 51.69, -1101.52),     V(6616.42, 441.77, 446.05)},
            {1625, "AmazonQuest2",         1, "Female Islander",       V(5446.87, 601.62, 749.46),      V(4685.26, 735.81, 815.34)},
            {1650, "AmazonQuest2",         2, "Giant Islander",        V(5446.87, 601.62, 749.46),      V(4729.09, 590.44, -36.98)},
            {1700, "MarineTreeIsland",     1, "Marine Commodore",      V(2180.07, 28.73, -6740.06),     V(2286.00, 73.13, -7159.81)},
            {1725, "MarineTreeIsland",     2, "Marine Rear Admiral",   V(2180.07, 28.73, -6740.06),     V(3656.77, 160.52, -7001.60)},
            {1775, "DeepForestIsland3",    1, "Fishman Raider",        V(-10581.66, 330.87, -8761.19),  V(-10407.53, 331.76, -8368.52)},
            {1800, "DeepForestIsland3",    2, "Fishman Captain",       V(-10581.66, 330.87, -8761.19),  V(-10994.70, 352.38, -9002.11)},
            {1825, "DeepForestIsland",     1, "Forest Pirate",         V(-13234.04, 331.49, -7625.40),  V(-13274.48, 332.38, -7769.58)},
            {1850, "DeepForestIsland",     2, "Mythological Pirate",   V(-13234.04, 331.49, -7625.40),  V(-13680.61, 501.08, -6991.19)},
            {1900, "DeepForestIsland2",    1, "Jungle Pirate",         V(-12680.38, 389.97, -9902.02),  V(-12256.16, 331.74, -10485.84)},
            {1925, "DeepForestIsland2",    2, "Musketeer Pirate",      V(-12680.38, 389.97, -9902.02),  V(-13457.90, 391.55, -9859.18)},
            {1975, "HauntedQuest1",        1, "Reborn Skeleton",       V(-9479.22, 141.22, 5566.09),    V(-8763.72, 165.72, 6159.86)},
            {2000, "HauntedQuest1",        2, "Living Zombie",         V(-9479.22, 141.22, 5566.09),    V(-10144.13, 138.63, 5838.09)},
            {2025, "HauntedQuest2",        1, "Demonic Soul",          V(-9516.99, 172.02, 6078.47),    V(-9505.34, 172.10, 6158.99)},
            {2050, "HauntedQuest2",        2, "Posessed Mummy",        V(-9516.99, 172.02, 6078.47),    V(-9582.02, 6.25, 6205.48)},
            {2075, "NutQuest1",            1, "Peanut Scout",          V(-2104.39, 38.13, -10194.22),   V(-2143.24, 47.72, -10029.99)},
            {2100, "NutQuest1",            2, "Peanut President",      V(-2104.39, 38.13, -10194.22),   V(-1859.35, 38.10, -10422.43)},
            {2125, "IceCreamIslandQuest",  1, "Ice Cream Chef",        V(-820.65, 65.82, -10965.80),    V(-872.25, 65.82, -10919.96)},
            {2150, "IceCreamIslandQuest",  2, "Ice Cream Commander",   V(-820.65, 65.82, -10965.80),    V(-558.06, 112.05, -11290.77)},
            {2200, "CakeQuest1",           1, "Cookie Crafter",        V(-2021.32, 37.80, -12028.73),   V(-2374.14, 37.80, -12125.31)},
            {2225, "CakeQuest1",           2, "Cake Guard",            V(-2021.32, 37.80, -12028.73),   V(-1598.31, 43.77, -12244.58)},
            {2250, "CakeQuest2",           1, "Baking Staff",          V(-1927.92, 37.80, -12842.54),   V(-1887.80, 77.62, -12998.35)},
            {2275, "CakeQuest2",           2, "Head Baker",            V(-1927.92, 37.80, -12842.54),   V(-2216.19, 82.88, -12869.29)},
            {2300, "ChocQuest1",           1, "Cocoa Warrior",         V(233.22, 29.88, -12201.23),     V(-21.07, 80.57, -12352.39)},
            {2325, "ChocQuest1",           2, "Chocolate Bar Battler", V(233.22, 29.88, -12201.23),     V(582.59, 77.19, -12463.16)},
            {2350, "ChocQuest2",           1, "Sweet Thief",          V(150.51, 30.69, -12774.50),     V(165.19, 76.81, -12600.84)},
            {2375, "ChocQuest2",           2, "Candy Rebel",           V(150.51, 30.69, -12774.50),     V(134.87, 77.44, -12876.54)},
            {2400, "CandyQuest1",          1, "Candy Pirate",          V(-1149.33, 13.02, -14445.61),   V(-1310.50, 26.02, -14562.40)},
            {2425, "CandyQuest1",          2, "Snow Demon",            V(-1149.33, 13.02, -14445.61),   V(-880.20, 71.25, -14538.61)},
            {2450, "TikiQuest1",           1, "Isle Outlaw",           V(-16547.75, 61.14, -173.41),    V(-16442.81, 116.14, -264.46)},
            {2475, "TikiQuest1",           2, "Island Boy",            V(-16547.75, 61.14, -173.41),    V(-16901.27, 84.07, -192.89)},
            {2500, "TikiQuest2",           1, "Sun-kissed Warrior",    V(-16539.08, 55.69, 1051.57),    V(-16349.84, 92.07, 1106.46)},
            {2525, "TikiQuest2",           2, "Isle Champio",          V(-16539.08, 55.69, 1051.57),    V(-16672.07, 21.79, 1123.28)}, 
            {2550, "TikiQuest3",           2, "Serpent Hunter",       V(-16658.09, 110.27, 1579.21),    V(-16566.11, 107.05, 1329.61)},
            {2575, "TikiQuest3",           2, "Skull Slayer",         V(-16658.09, 110.27, 1579.21),    V(-16818.82, 71.27, 1635.02)},

            -- ================= SUBMERGED ISLAND =================
            -- 2600-2800: tự động đi qua Submarine Worker rồi farm dưới nước
            {2600, "SubmergedQuest1",     1, "Reef Bandit",             V(10778.875, -2087.724, 9265.184), V(11019.132, -2146.068, 9342.392)},
            {2625, "SubmergedQuest1",     2, "Coral Pirate",            V(10778.875, -2087.724, 9265.184), V(10808.601, -2030.361, 9364.233)},
            {2650, "SubmergedQuest2",     1, "Sea Chanter",              V(10880.686, -2086.200, 10032.624), V(10671.272, -2057.592, 10047.259)},
            {2675, "SubmergedQuest2",     2, "Ocean Prophet",            V(10880.686, -2086.200, 10032.624), V(11008.520, -2007.728, 10223.079)},
            {2700, "SubmergedQuest3",     1, "High Disciple",             V(9640.088, -1992.445, 9613.652), V(9750.416, -1966.939, 9753.360)},
            {2725, "SubmergedQuest3",     2, "Grand Devotee",             V(9640.088, -1992.445, 9613.652), V(9611.705, -1993.471, 9882.688)},
        },
    }

    function GetQuestData()
        local level = getLevel()
        local list = World1 and QUESTS[1] or (World2 and QUESTS[2] or QUESTS[3])
        local pick = list[1]
        for _, q in ipairs(list) do
            if level >= q[1] then pick = q else break end
        end
        -- tên quest, số quest, tên quái, vị trí NPC, vị trí quái
        return pick[2], pick[3], pick[4], pick[5], pick[6]
    end

    local spawnCache = {}
    local function norm(n)
        local s = string.lower(tostring(n))
        s = string.gsub(s, "%s*%[.-%]%s*$", "")
        s = string.gsub(s, "possessed", "posessed")
        return s
    end

    -- Tìm điểm hồi sinh THẬT của quái trong workspace._WorldOrigin.EnemySpawns
    -- (gần vị trí dự phòng nhất). Trả về nil nếu không tìm thấy.
    function GetQuestMobSpawn(mobName, nearPos)
        if not mobName then return nil end
        local cached = spawnCache[mobName]
        if cached and tick() - cached.t < 10 then return cached.pos end

        local want = norm(mobName)
        local origin = nearPos
        if not origin then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            origin = hrp and hrp.Position
        end

        local best, bestDist = nil, math.huge
        local wo = workspace:FindFirstChild("_WorldOrigin")
        local spawns = wo and wo:FindFirstChild("EnemySpawns")
        if spawns then
            for pass = 1, 2 do
                for _, sp in ipairs(spawns:GetChildren()) do
                    local n = norm(sp.Name)
                    if (pass == 1 and n == want) or (pass == 2 and string.find(n, want, 1, true)) then
                        local pos
                        if sp:IsA("BasePart") then
                            pos = sp.Position
                        else
                            local ok, cf = pcall(function() return sp:GetPivot() end)
                            pos = ok and cf and cf.Position or nil
                        end
                        if pos then
                            local d = origin and (pos - origin).Magnitude or 0
                            if d < bestDist then best, bestDist = pos, d end
                        end
                    end
                end
                if best then break end
            end
        end

        spawnCache[mobName] = {t = tick(), pos = best}
        return best
    end
end

-- HÀM LẤY NHIỆM VỤ ĐẢO XƯƠNG (HAUNTED CASTLE) DỰA THEO CẤP ĐỘ
local function GetHauntedQuestData()
    local level = getLevel()
    if level < 2000 then
        return "HauntedQuest1", 1, "Reborn Skeleton", Vector3.new(-9479.22, 141.22, 5566.09), Vector3.new(-8763.72, 165.72, 6159.86)
    elseif level < 2025 then
        return "HauntedQuest1", 2, "Living Zombie", Vector3.new(-9479.22, 141.22, 5566.09), Vector3.new(-10144.13, 138.63, 5838.09)
    elseif level < 2050 then
        return "HauntedQuest2", 1, "Demonic Soul", Vector3.new(-9516.99, 172.02, 6078.47), Vector3.new(-9505.34, 172.10, 6158.99)
    else
        return "HauntedQuest2", 2, "Posessed Mummy", Vector3.new(-9516.99, 172.02, 6078.47), Vector3.new(-9582.02, 6.25, 6205.48)
    end
end

-- ===================== HỆ THỐNG QUÉT QUEST =====================
-- Vấn đề cũ: chỉ dựa vào Main.Quest.Visible. Nếu bản game của bạn dùng giao diện quest khác
-- thì script luôn tưởng "chưa có quest" -> nhận lại liên tục. Bản này dùng 3 lớp phát hiện:
--   (1) Main.Quest.Visible (kiểu cũ)
--   (2) quét mọi TextLabel đang hiện có chữ "Defeat ... <tên quái>" (kiểu giao diện mới)
--   (3) dự phòng: tự đếm số quái đã giết từ lúc nhận quest, đủ số mới nhận tiếp

-- (Gom biến vào bảng Q vì Luau giới hạn 200 biến local ở cấp cao nhất)
local Q = {
    QUEST_DEBUG = true,          -- in log [Quest] ra console (F9)
    QUEST_HIDE_GRACE = 0.5,      -- quest vừa xong -> chờ rồi nhận quest mới
    QUEST_LOST_WAIT = 10,        -- GUI tắt khi CHƯA đánh đủ -> chờ lâu hơn
    QUEST_RETRY_DELAY = 4,       -- tối thiểu giữa 2 lần gọi StartQuest
    QUEST_RESPAWN_WAIT = 5,      -- chờ GUI load lại sau khi hồi sinh
    QUEST_DEFAULT_KILLS = 8,     -- số quái mặc định khi không đọc được tiến độ (chế độ dự phòng)
    QUEST_MAX_TIME = 240,        -- chế độ dự phòng: tối đa bao lâu coi là còn quest
    questAttempts = 0, lastQuestAttempt = 0, questGiveUpUntil = 0,
    acceptedQuestKey = nil,
    lastQuestSeen = 0,
    lastCharSpawn = tick(),
    lastCur = nil, lastTotal = nil,
    genericSeenAt = 0,
    currentQuestMobName = nil,
    guiDetectionWorks = false,
    questAcceptedAt = 0,
    killsSinceAccept = 0,
    hookedMobs = setmetatable({}, {__mode = "k"}),
}

function Q.qlog(...)
    if Q.QUEST_DEBUG then print("[Quest]", ...) end
end

local function getCommF()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    return remotes and remotes:FindFirstChild("CommF_")
end

-- Chuẩn hoá tên quái: bỏ "[Lv. x]", gộp chính tả "Possessed/Posessed"
function Q.normMob(n)
    local s = string.lower(tostring(n))
    s = string.gsub(s, "%s*%[.-%]%s*$", "")
    s = string.gsub(s, "possessed", "posessed")
    return s
end

-- 2 = trùng tên hoàn toàn, 1 = tên chứa tên quest, 0 = không khớp
function Q.mobMatches(enemyName, questMob)
    if not questMob then return 0 end
    local a, b = Q.normMob(enemyName), Q.normMob(questMob)
    if a == b then return 2 end
    if string.find(a, b, 1, true) then return 1 end
    return 0
end

-- SEA 1: CỔNG VÀO UNDERWATER CITY (đảo dưới nước / Fishman).
-- Lỗi cũ: script gọi requestEntrance ngay tại chỗ đang đứng nên không vào được. Phải BAY TỚI CỔNG VÀO trước,
-- tới sát cổng rồi mới gọi requestEntrance thì game mới dịch chuyển xuống thành phố.
-- Nếu cổng không đúng chỗ trên bản game của bạn, sửa toạ độ ở Q.FISHMAN_GATE.
Q.FISHMAN_GATE = Vector3.new(4055.44, -3.97, -1812.64)   -- tâm xoáy nước vào Underwater City (toạ độ do bạn cung cấp)
Q.flyingToGate = false
-- Thời gian ĐỨNG CHỜ ở cổng (giây) để game kịp dịch chuyển xuống / lên Underwater City (chỉnh trong tab Config).
Q.PORTAL_WAIT = 6
Q.gatePart = nil
Q.gateScanAt = -100

-- Cổng vào Underwater City là XOÁY NƯỚC (whirlpool) giữa 3 hòn đá, nằm giữa Frozen Village và Prison.
-- Chạm vào tâm xoáy nước là được dịch chuyển xuống thành phố. Ưu tiên tìm part "whirlpool" thật trong map,
-- nếu không thấy thì dùng toạ độ dự phòng Q.FISHMAN_GATE.
function Q.getGate()
    if tick() - Q.gateScanAt > 30 then
        Q.gateScanAt = tick()
        Q.gatePart = nil
        local map = workspace:FindFirstChild("Map")
        if map then
            local best, bestD = nil, 2500
            for _, d in ipairs(map:GetDescendants()) do
                if d:IsA("BasePart") and string.find(string.lower(d.Name), "whirlpool", 1, true) then
                    local dd = (d.Position - Q.FISHMAN_GATE).Magnitude
                    if dd < bestD then best, bestD = d, dd end
                end
            end
            Q.gatePart = best
        end
    end
    if Q.gatePart and Q.gatePart.Parent then return Q.gatePart.Position, Q.gatePart end
    return Q.FISHMAN_GATE, nil
end

-- Trả về true nếu còn đang bay tới cổng (vòng farm nên chờ frame sau); false nếu đã ở sát cổng.
function Q.flyToFishmanGate(hrp)
    local gate = Q.getGate()
    local dist = (hrp.Position - gate).Magnitude

    if dist > 25 then
        Q.gateArriveAt = nil
        if not currentFlyTween or not Q.flyingToGate then
            if currentFlyTween then pcall(function() currentFlyTween:Cancel() end) end
            Q.flyingToGate = true
            local target = CFrame.new(gate + Vector3.new(0, 3, 0))
            local tw = TweenService:Create(hrp, TweenInfo.new(dist / flySpeed, Enum.EasingStyle.Linear), {CFrame = target})
            currentFlyTween = tw
            tw:Play()
            tw.Completed:Connect(function()
                if currentFlyTween == tw then currentFlyTween = nil end
                Q.flyingToGate = false
            end)
            Q.qlog("Sea 1: bay tới cổng vào Underwater City", gate)
        end
        return true
    end
    -- đã tới sát cổng: dừng tween & đứng yên trước khi gọi requestEntrance
    if currentFlyTween and Q.flyingToGate then
        pcall(function() currentFlyTween:Cancel() end)
        currentFlyTween = nil
    end
    Q.flyingToGate = false
    -- Trong luồng mua võ, giữ nguyên vị trí đạt được bằng đường bay; chỉ căn nhẹ
    -- ở cổng cho các luồng khác để không biến hành trình mua Fishman thành teleport.
    if not (_G.BuyMeleeActive == true) then
        hrp.CFrame = CFrame.new(gate + Vector3.new(0, 2, 0))
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    -- ĐỨNG CHỜ ở cổng một khoảng thời gian rồi mới chạm xoáy / gọi requestEntrance
    if not Q.gateArriveAt then
        Q.gateArriveAt = tick()
        Q.qlog("Sea 1: tới cổng, chờ " .. Q.PORTAL_WAIT .. "s trước khi xuống đảo dưới nước")
    end
    if tick() - Q.gateArriveAt < Q.PORTAL_WAIT then return true end
    local _, part = Q.getGate()
    if part and typeof(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(hrp, part, 0)
            firetouchinterest(hrp, part, 1)
        end)
    end
    return false
end

-- SEA 1: ĐIỂM THOÁT UNDERWATER CITY.
-- Farm level xong ở đảo dưới nước (level 450+ nhiệm vụ kế tiếp nằm trên mặt biển / Sky Island) thì bay tới
-- toạ độ này để rời thành phố trước khi đi tới mục tiêu kế tiếp.
Q.UNDERWATER_EXIT = Vector3.new(61171.62, -3.95, 1953.0)
Q.flyingToExit = false
-- Điểm thoát dùng riêng cho Auto Pickup Fruit: đang ở Underwater City mà trái rơi ở ngoài -> bay tới đây trước.
Q.UNDERWATER_FRUIT_EXIT = Vector3.new(61171.62, -3.95, 1953.09)

-- Trả về true nếu còn đang bay tới / chờ dịch chuyển ở điểm thoát (vòng farm nên chờ), false khi xong/bỏ cuộc.
function Q.flyToUnderwaterExit(hrp)
    local ex = Q.UNDERWATER_EXIT
    local dist = (hrp.Position - ex).Magnitude
    if dist > 15 then
        Q.exitNearAt = nil
        if not currentFlyTween or not Q.flyingToExit then
            if currentFlyTween then pcall(function() currentFlyTween:Cancel() end) end
            Q.flyingToExit = true
            local tw = TweenService:Create(hrp, TweenInfo.new(dist / flySpeed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(ex + Vector3.new(0, 2, 0))})
            currentFlyTween = tw
            tw:Play()
            tw.Completed:Connect(function()
                if currentFlyTween == tw then currentFlyTween = nil end
                Q.flyingToExit = false
            end)
            Q.qlog("Sea 1: xong Underwater City -> bay tới điểm thoát", ex)
        end
        return true
    end

    if currentFlyTween and Q.flyingToExit then
        pcall(function() currentFlyTween:Cancel() end)
        currentFlyTween = nil
    end
    Q.flyingToExit = false
    Q.exitNearAt = Q.exitNearAt or tick()
    hrp.CFrame = CFrame.new(ex + Vector3.new(0, 2, 0))
    hrp.AssemblyLinearVelocity = Vector3.zero

    -- chạm thử các part cổng / xoáy / portal gần điểm thoát để được dịch chuyển ra ngoài
    if typeof(firetouchinterest) == "function" and tick() - Q.exitNearAt >= Q.PORTAL_WAIT and tick() - (Q.exitTouchAt or 0) > 2 then
        Q.exitTouchAt = tick()
        local map = workspace:FindFirstChild("Map")
        if map then
            for _, d in ipairs(map:GetDescendants()) do
                if d:IsA("BasePart") and (d.Position - ex).Magnitude <= 80 then
                    local n = string.lower(d.Name)
                    if string.find(n, "whirlpool", 1, true) or string.find(n, "portal", 1, true) or string.find(n, "exit", 1, true)
                        or string.find(n, "gate", 1, true) or string.find(n, "teleport", 1, true) then
                        pcall(function() firetouchinterest(hrp, d, 0); firetouchinterest(hrp, d, 1) end)
                    end
                end
            end
        end
    end

    -- chờ dịch chuyển tối đa 25 giây; quá thời gian thì thôi để farm không bị kẹt mãi ở đây
    if tick() - Q.exitNearAt > Q.PORTAL_WAIT + 25 then
        Q.qlog("Sea 1: đứng ở điểm thoát 25s mà chưa ra ngoài -> bỏ qua")
        return false
    end
    return true
end

-- =========================================================
-- SUBMERGED: MỞ HỘI THOẠI SUBMARINE WORKER + TỰ BẤM NÚT "Yes"
-- (dùng khi remote RF/SubmarineWorkerSpeak không đưa được xuống)
-- =========================================================
function Q.submergedFindWorker()
    local best, bestScore = nil, math.huge
    local expected = SUBMERGED_WORKER_POS

    -- Ưu tiên đúng NPC ở Tiki Outpost, tránh lấy nhầm một part trùng tên.
    pcall(function()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.Name == "Submarine Worker" and (v:IsA("Model") or v:IsA("BasePart")) then
                local pos
                if v:IsA("BasePart") then
                    pos = v.Position
                else
                    local ok, pivot = pcall(function() return v:GetPivot() end)
                    if ok and pivot then pos = pivot.Position end
                end
                if pos then
                    local score = (pos - expected).Magnitude
                    if not v:IsA("Model") then score = score + 3 end
                    if score < bestScore then
                        best, bestScore = v, score
                    end
                end
            end
        end
    end)
    return best
end

function Q.submergedOpenDialog(worker)
    if not worker then return false end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local wpos
    pcall(function()
        wpos = worker:IsA("BasePart") and worker.Position or worker:GetPivot().Position
    end)

    -- Quay mặt về phía NPC
    if root and wpos then
        pcall(function()
            root.CFrame = CFrame.lookAt(root.Position, Vector3.new(wpos.X, root.Position.Y, wpos.Z))
        end)
    end

    local found = false

    -- 1) ProximityPrompt (trong NPC; nếu không có thì tìm prompt gần NPC)
    local prompts = {}
    pcall(function()
        for _, p in ipairs(worker:GetDescendants()) do
            if p:IsA("ProximityPrompt") then table.insert(prompts, p) end
        end
        if #prompts == 0 and wpos then
            for _, p in ipairs(workspace:GetDescendants()) do
                if p:IsA("ProximityPrompt") then
                    local par = p.Parent
                    local pp = par and (par:IsA("BasePart") and par.Position or (par:IsA("Attachment") and par.WorldPosition))
                    if pp and (pp - wpos).Magnitude < 25 then table.insert(prompts, p) end
                end
            end
        end
    end)
    for _, p in ipairs(prompts) do
        found = true
        pcall(function()
            p.Enabled = true
            p.HoldDuration = 0
            p.RequiresLineOfSight = false
            if p.MaxActivationDistance < 30 then p.MaxActivationDistance = 30 end
        end)
        if typeof(fireproximityprompt) == "function" then
            pcall(fireproximityprompt, p)
        end
        -- Fallback bằng phím thật kể cả khi fireproximityprompt tồn tại nhưng không mở hội thoại.
        if okVIM and VirtualInputManager then
            pcall(function()
                local key = p.KeyboardKeyCode ~= Enum.KeyCode.Unknown and p.KeyboardKeyCode or Enum.KeyCode.E
                VirtualInputManager:SendKeyEvent(true, key, false, game)
                task.wait(0.15)
                VirtualInputManager:SendKeyEvent(false, key, false, game)
            end)
        end
    end

    -- 2) ClickDetector
    pcall(function()
        for _, cd in ipairs(worker:GetDescendants()) do
            if cd:IsA("ClickDetector") then
                found = true
                if typeof(fireclickdetector) == "function" then fireclickdetector(cd) end
            end
        end
    end)

    -- 3) Dự phòng thêm: click vào NPC trên màn hình kể cả khi prompt đã được thử nhưng không phản hồi
    if okVIM and VirtualInputManager and wpos then
        pcall(function()
            local cam = workspace.CurrentCamera
            local v, onScreen = cam:WorldToViewportPoint(wpos + Vector3.new(0, 1.5, 0))
            if onScreen then
                local inset = game:GetService("GuiService"):GetGuiInset()
                VirtualInputManager:SendMouseButtonEvent(v.X, v.Y + inset.Y, 0, true, game, 0)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(v.X, v.Y + inset.Y, 0, false, game, 0)
            end
        end)
    end
    return found
end

-- GUI có đang hiển thị thật sự không (kiểm tra cả chuỗi cha)
function Q.submergedGuiVisible(o, pg)
    local n = o
    while n and n ~= pg do
        if n:IsA("GuiObject") and not n.Visible then return false end
        if n:IsA("ScreenGui") and not n.Enabled then return false end
        n = n.Parent
    end
    return true
end

-- Tìm nút theo chữ (vd "yes"); trả về GuiButton hoặc khung chứa chữ
function Q.submergedFindButton(word)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, v in ipairs(pg:GetDescendants()) do
        if (v:IsA("TextLabel") or v:IsA("TextButton")) and Q.submergedGuiVisible(v, pg) then
            local t = tostring(v.Text):gsub("%s", ""):lower()
            if t == word and v.AbsoluteSize.X > 0 then
                local node = v
                while node and node ~= pg do
                    if node:IsA("GuiButton") then return node end
                    node = node.Parent
                end
                return v.Parent
            end
        end
    end
    return nil
end

function Q.submergedFindYesButton()
    return Q.submergedFindButton("yes")
end

-- Đọc câu thoại NPC đang hiện (để log + nhận biết bước mời xuống đảo)
function Q.submergedDialogText()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return "" end
    local best = ""
    for _, v in ipairs(pg:GetDescendants()) do
        if v:IsA("TextLabel") and Q.submergedGuiVisible(v, pg) then
            local t = tostring(v.Text)
            if #t > 20 and #t > #best and v.AbsoluteSize.X > 100 then best = t end
        end
    end
    return best
end

function Q.submergedInside()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local p = root.Position
    local dx, dz = p.X - 10480, p.Z - 9800
    return p.Y < SUBMERGED_Y and (dx * dx + dz * dz) <= (4300 * 4300)
end

function Q.submergedClickGui(obj)
    if not obj then return false end
    if typeof(firesignal) == "function" and obj:IsA("GuiButton") then
        pcall(function() firesignal(obj.MouseButton1Down) end)
        pcall(function() firesignal(obj.MouseButton1Click) end)
        pcall(function() firesignal(obj.MouseButton1Up) end)
        pcall(function() firesignal(obj.Activated) end)
    end
    if okVIM and VirtualInputManager then
        pcall(function()
            local inset = game:GetService("GuiService"):GetGuiInset()
            local pos, size = obj.AbsolutePosition, obj.AbsoluteSize
            local x = pos.X + size.X / 2
            local y = pos.Y + size.Y / 2 + inset.Y
            VirtualInputManager:SendMouseMoveEvent(x, y, game)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end
    return true
end

-- Hội thoại nhiều bước: cứ thấy nút "Yes" là bấm, lặp tới khi xuống được đảo.
-- Trả về true nếu đã bấm được ít nhất 1 lần.
function Q.submergedViaDialog(worker)
    Q.submergedOpenDialog(worker)
    local clickedAny, lastClick, lastOpen, lastText = false, 0, tick(), ""
    for _ = 1, 45 do   -- tối đa ~13 giây
        task.wait(0.3)
        if Q.submergedInside() then return true end

        local txt = Q.submergedDialogText()
        if txt ~= "" and txt ~= lastText then
            lastText = txt
            Q.qlog("Submerged: NPC nói -> " .. txt:sub(1, 80))
        end

        local btn = Q.submergedFindYesButton()
        if btn then
            if tick() - lastClick > 0.8 then
                lastClick = tick()
                clickedAny = true
                Q.qlog("Submerged: bấm Yes")
                Q.submergedClickGui(btn)
            end
        elseif tick() - lastOpen > 2.5 and not clickedAny then
            -- chưa có hộp thoại -> mở lại (nói chuyện lại với NPC)
            lastOpen = tick()
            Q.submergedOpenDialog(worker)
        end
    end
    return clickedAny
end

-- Nhận diện Thuyền Ma dùng chung cho Auto Level, Boss, Material và các luồng di chuyển.
-- Vùng được nới rộng để không đổi phía cổng khi NPC di chuyển/đứng sát mép thân tàu.
Q.CURSED_SHIP_CONFIRM_SECONDS = 0.55
Q.CursedShipTargetSideStates = Q.CursedShipTargetSideStates or {}

function Q.isCursedShipPosition(pos)
    return pos ~= nil
        and pos.X >= 500 and pos.X <= 1700
        and pos.Z >= 32200 and pos.Z <= 34100
end

-- Trả về side ổn định và cờ pending. Khi mục tiêu vừa đổi phía, phải thấy vị trí mới
-- ổn định đủ 0,55 giây; trong thời gian xác nhận, caller phải đợi thay vì tự bay thẳng.
function Q.getStableCursedShipTargetSide(pos, sourceKey, forceInside)
    -- Cursed Captain là boss thuộc Thuyền Ma kể cả khi HRP tạm lệch khỏi vùng tọa độ.
    local rawInside = forceInside == true or Q.isCursedShipPosition(pos)
    local key = tostring(sourceKey or "default")
    local now = tick()
    local states = Q.CursedShipTargetSideStates
    local state = states[key]

    if not state then
        -- Lần đầu quan sát cũng cần xác nhận, tránh một tọa độ NPC vừa stream sai làm chọn cổng ngay.
        state = {stable = nil, candidate = rawInside, candidateSince = now}
        states[key] = state
        return rawInside, true
    end

    if state.stable == nil then
        if rawInside ~= state.candidate then
            state.candidate = rawInside
            state.candidateSince = now
        end
        if now - (state.candidateSince or now) >= Q.CURSED_SHIP_CONFIRM_SECONDS then
            state.stable = rawInside
            state.candidate = rawInside
            state.candidateSince = now
            return state.stable, false
        end
        return rawInside, true
    end

    if rawInside == state.stable then
        state.candidate = rawInside
        state.candidateSince = now
        return state.stable, false
    end

    if state.candidate ~= rawInside then
        state.candidate = rawInside
        state.candidateSince = now
    end

    if now - (state.candidateSince or now) >= Q.CURSED_SHIP_CONFIRM_SECONDS then
        state.stable = rawInside
        state.candidate = rawInside
        state.candidateSince = now
        return state.stable, false
    end

    return state.stable, true
end

-- Fishman Island (Sea 1), Cursed Ship (Sea 2) và Submerged Island (Sea 3)
-- cần bước vào bằng remote đặc biệt. Với Submerged Island, script tự
-- tới khu Submarine Worker ở Tiki Outpost rồi gọi "TravelToSubmergedIsland"
-- (tương đương bấm Yes trong hộp thoại).
function Q.enterIfNeeded(hrp, pos, sourceKey, targetName)
    if not hrp or not pos then return false end

    -- =========================================================
    -- SEA 2: CURSED SHIP SHARED TRANSIT COORDINATOR
    -- Các hệ thống gọi Q.enterIfNeeded đều dùng chung luồng này:
    -- Auto Level/Quest, farm mục tiêu/Boss, Material, Auto Chest và Auto Pickup Fruit.
    -- Điểm (-6500.94, 87.60, -123.19) là mốc phía Graveyard do người dùng cung cấp;
    -- requestEntrance cần tọa độ cổng hợp lệ riêng ở mỗi đầu.
    -- =========================================================
    if World2 then
        local shipEntrance = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125)
        -- Điểm requestEntrance phía Graveyard (tọa độ remote chuẩn của lối ngoài).
        local graveyardExitRemote = Vector3.new(-6508.5581054688, 5000.034996032715, -132.83953857422)
        -- Mốc mặt đất chính xác theo người dùng cung cấp, dùng để kiểm tra/log vị trí thoát.
        local graveyardExitAnchor = Vector3.new(-6500.94, 87.60, -123.19)
        -- Điểm cửa thoát BÊN TRONG Thuyền Ma (do người dùng cung cấp): phải bay tới đây trước rồi mới requestEntrance để ra ngoài.
        local shipExitAnchor = Vector3.new(922.90, 128.40, 32841.96)

        local forceShipTarget = string.find(string.lower(tostring(targetName or "")), "cursed captain", 1, true) ~= nil
        local targetInShip, targetSidePending = Q.getStableCursedShipTargetSide(pos, sourceKey, forceShipTarget)
        local playerInShip = Q.isCursedShipPosition(hrp.Position)
        Q.CursedShipTransit = Q.CursedShipTransit or {
            phase = "idle", direction = nil, nextAttemptAt = 0, attempts = 0
        }
        local transit = Q.CursedShipTransit

        -- Vị trí mục tiêu vừa đổi phía: chờ xác nhận 0,55 giây, không gọi cổng và không bay xuyên map.
        if targetSidePending then
            transit.phase = "confirming-target-side"
            return true
        end

        -- Nếu người chơi và mục tiêu cùng phía cổng thì không can thiệp đường bay.
        if targetInShip == playerInShip then
            transit.phase = playerInShip and "inside" or "outside"
            transit.direction = nil
            transit.nextAttemptAt = 0
            transit.attempts = 0
        else
            local direction = targetInShip and "enter" or "exit"
            local now = tick()
            if now < (transit.nextAttemptAt or 0) then
                return true
            end

            if transit.direction ~= direction then
                transit.direction = direction
                transit.attempts = 0
            end
            transit.phase = direction == "enter" and "entering" or "exiting"
            transit.nextAttemptAt = now + 5

            local commF = getCommF()
            if not commF then
                transit.phase = "waiting-remote"
                transit.nextAttemptAt = now + 1.5
                Q.qlog("Cursed Ship: chưa tìm thấy CommF_, sẽ thử lại")
                return true
            end

            -- Khi vào Thuyền Ma, BAY ĐẾN cổng phía Graveyard do người dùng cung cấp trước.
            -- Không gọi requestEntrance ngay từ vị trí bất kỳ; sau khi đến gần cổng mới yêu cầu chuyển khu.
            if direction == "enter" then
                local liveChar = LocalPlayer.Character
                local liveRoot = liveChar and liveChar:FindFirstChild("HumanoidRootPart")
                if not liveRoot then
                    transit.phase = "waiting-character"
                    transit.nextAttemptAt = tick() + 1
                    return true
                end
                local gateDistance = (liveRoot.Position - graveyardExitAnchor).Magnitude
                if gateDistance > 85 then
                    transit.phase = "flying-to-graveyard-gate"
                    Q.qlog("Sea 2 Level 1250+: đang bay tới cổng Thuyền Ma ở Graveyard", graveyardExitAnchor)
                    local okFly, flyErr = pcall(function()
                        flyTo(CFrame.new(graveyardExitAnchor + Vector3.new(0, 5, 0)), math.max(flySpeed or 190, 220), function()
                            local currentChar = LocalPlayer.Character
                            local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
                            return currentRoot ~= nil and (
                                autoFarmEnabled
                                or autoFarmMaterialEnabled
                                or autoRaidEnabled
                                or _G.Dungeon == true
                                or autoChestEnabled
                                or _G.FruitPickupBusy == true
                                or _G.AutoFarm == true
                                or _G.BuyMeleeActive == true
                            )
                        end)
                    end)
                    if not okFly then
                        transit.phase = "retry-enter-flight"
                        transit.attempts = (transit.attempts or 0) + 1
                        transit.nextAttemptAt = tick() + math.min(6, 1.5 + transit.attempts * 1.25)
                        Q.qlog("Cursed Ship: lỗi khi bay tới cổng", tostring(flyErr))
                        return true
                    end
                    local afterChar = LocalPlayer.Character
                    local afterRoot = afterChar and afterChar:FindFirstChild("HumanoidRootPart")
                    if not afterRoot or (afterRoot.Position - graveyardExitAnchor).Magnitude > 130 then
                        transit.phase = "retry-enter-flight"
                        transit.nextAttemptAt = tick() + 1.5
                        Q.qlog("Cursed Ship: chưa đến sát cổng Graveyard; sẽ thử lại")
                        return true
                    end
                    hrp = afterRoot
                    task.wait(0.35)
                end
            end

            -- THOÁT Thuyền Ma: bay tới cửa thoát (922.90, 128.40, 32841.96) trước, tới sát mới gọi requestEntrance.
            -- Áp dụng chung cho: mua melee, farm nguyên liệu, farm boss, auto chest, start raid, nhặt trái.
            if direction == "exit" then
                local liveChar = LocalPlayer.Character
                local liveRoot = liveChar and liveChar:FindFirstChild("HumanoidRootPart")
                if not liveRoot then
                    transit.phase = "waiting-character"
                    transit.nextAttemptAt = tick() + 1
                    return true
                end
                if (liveRoot.Position - shipExitAnchor).Magnitude > 25 then
                    transit.phase = "flying-to-ship-exit"
                    Q.qlog("Thuyền Ma: đang bay tới cửa thoát", shipExitAnchor)
                    local okFly, flyErr = pcall(function()
                        flyTo(CFrame.new(shipExitAnchor), math.max(flySpeed or 190, 220), function()
                            local currentRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            return currentRoot ~= nil and (
                                autoFarmEnabled
                                or autoFarmMaterialEnabled
                                or autoRaidEnabled
                                or autoStartRaidEnabled
                                or _G.StartRaid == true
                                or _G.AutoBuyChip == true
                                or _G.Dungeon == true
                                or autoChestEnabled
                                or _G.FruitPickupBusy == true
                                or _G.AutoPickupFruit == true
                                or _G.AutoFarm == true
                                or _G.BuyMeleeActive == true
                            )
                        end)
                    end)
                    local afterRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if not okFly or not afterRoot or (afterRoot.Position - shipExitAnchor).Magnitude > 40 then
                        transit.phase = "retry-exit-flight"
                        transit.attempts = (transit.attempts or 0) + 1
                        transit.nextAttemptAt = tick() + 1.5
                        Q.qlog("Thuyền Ma: chưa tới sát cửa thoát; sẽ thử lại", okFly and "" or tostring(flyErr))
                        return true
                    end
                    hrp = afterRoot
                    task.wait(0.35)
                end
            end

            local requestedEntrance = targetInShip and shipEntrance or graveyardExitRemote
            Q.qlog(
                direction == "enter" and "Sea 2: đã tới cổng Graveyard, đang vào Thuyền Ma" or "Sea 2: đang thoát Thuyền Ma",
                direction == "enter" and graveyardExitAnchor or graveyardExitAnchor
            )

            local okEntrance, entranceErr = pcall(function()
                commF:InvokeServer("requestEntrance", requestedEntrance)
            end)

            if not okEntrance then
                transit.attempts = (transit.attempts or 0) + 1
                transit.phase = "retry-" .. direction
                transit.nextAttemptAt = tick() + math.min(6, 1.5 + transit.attempts * 1.25)
                Q.qlog("Cursed Ship: requestEntrance lỗi", tostring(entranceErr))
                return true
            end

            -- Chờ server cập nhật vị trí trước khi đánh giá cổng đã hoạt động chưa.
            local reachedExpectedSide = false
            for _ = 1, 10 do
                task.wait(0.15)
                local liveChar = LocalPlayer.Character
                local liveRoot = liveChar and liveChar:FindFirstChild("HumanoidRootPart")
                if liveRoot and Q.isCursedShipPosition(liveRoot.Position) == targetInShip then
                    hrp = liveRoot
                    reachedExpectedSide = true
                    break
                end
            end

            if reachedExpectedSide then
                transit.phase = targetInShip and "inside" or "outside"
                transit.direction = nil
                transit.attempts = 0
                transit.nextAttemptAt = tick() + 0.75
                if not targetInShip then
                    local liveRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if liveRoot and (liveRoot.Position - graveyardExitAnchor).Magnitude <= 220 then
                        Q.qlog("Cursed Ship: đã thoát gần điểm Graveyard được cấu hình", graveyardExitAnchor)
                    else
                        Q.qlog("Cursed Ship: đã chuyển ra ngoài, tiếp tục tới mục tiêu farm")
                    end
                else
                    Q.qlog("Cursed Ship: đã vào khu vực thuyền, tiếp tục Auto Farm/Quest")
                end
            else
                transit.attempts = (transit.attempts or 0) + 1
                transit.phase = "retry-" .. direction
                transit.nextAttemptAt = tick() + math.min(6, 1.5 + transit.attempts * 1.25)
                Q.qlog("Cursed Ship: chưa xác nhận được vị trí sau khi qua cổng; sẽ thử lại")
            end
            -- Dừng vòng hiện tại để các loop không bay đồng thời trong lúc đổi khu vực.
            return true
        end
    end

    -- =========================================================
    -- SEA 3: SUBMERGED ISLAND
    -- Level 2600+ phải nói chuyện với Submarine Worker ở Tiki Outpost,
    -- sau đó gọi đúng RemoteFunction RF/SubmarineWorkerSpeak.
    -- Chỉ trả về false khi đã xác nhận nhân vật thật sự ở dưới nước.
    -- =========================================================
    if World3 and pos.Y < -1000 then
        local function getRoot()
            local char = LocalPlayer.Character
            return char and char:FindFirstChild("HumanoidRootPart")
        end

        local function isInsideSubmerged()
            local root = getRoot()
            if not root then return false end
            local p = root.Position
            local questCenter = Vector3.new(10480, -2050, 9800)
            local dx, dz = p.X - questCenter.X, p.Z - questCenter.Z
            return p.Y < SUBMERGED_Y and (dx * dx + dz * dz) <= (4300 * 4300)
        end

        local function confirmedEntry()
            submergedTravelBusy = false
            submergedTravelAttempts = 0
            if Q.SUB and Q.SUB.set then Q.SUB.set("Đã xuống đảo dưới nước") end
            Q.qlog("Submerged: xác nhận đã xuống đảo dưới nước")
            return false
        end

        local function accessDenied()
            local txt = string.lower(Q.submergedDialogText())
            return string.find(txt, "occupied", 1, true) ~= nil
                or string.find(txt, "so many bandits", 1, true) ~= nil
        end

        local function waitForEntry(seconds)
            local deadline = tick() + seconds
            while tick() < deadline do
                task.wait(0.2)
                if isInsideSubmerged() then return true end
            end
            return isInsideSubmerged()
        end

        if isInsideSubmerged() then return confirmedEntry() end

        -- Không cho Auto Level bay tới vị trí quái dưới nước khi đang xử lý chuyến đi.
        if submergedTravelBusy then
            if tick() - submergedTravelLast < 10 then return true end
            submergedTravelBusy = false
        end
        if tick() - submergedTravelLast < 1.25 then return true end

        submergedTravelLast = tick()
        submergedTravelAttempts = submergedTravelAttempts + 1
        submergedTravelBusy = true

        -- Tìm NPC thật trước; chỉ dùng tọa độ dự phòng khi NPC chưa load.
        local worker = Q.submergedFindWorker()
        local workerPos = SUBMERGED_WORKER_POS
        if worker then
            pcall(function()
                workerPos = worker:IsA("BasePart") and worker.Position or worker:GetPivot().Position
            end)
        end

        Q.qlog("Submerged: tới Submarine Worker, lần " .. tostring(submergedTravelAttempts))
        local root = getRoot()
        if not root then
            submergedTravelBusy = false
            return true
        end

        -- DI CHUYỂN THEO 2 CHẶNG: bay lên cao trước, sau đó áp sát Submarine Worker.
        -- Dùng autoFarmEnabled (biến nội bộ menu), không chỉ dựa vào _G.AutoFarm,
        -- vì script Minh Hub không dùng _G.AutoFarm làm trạng thái chính.
        local function canContinueSubmergedTravel()
            return (autoFarmEnabled or (Q.SUB and Q.SUB.force) or (Q.DK and Q.DK.on) or _G.AutoFarm == true)
                and LocalPlayer.Character ~= nil
        end

        root = getRoot()
        if not root then
            submergedTravelBusy = false
            return true
        end

        local aboveWorker = CFrame.new(workerPos + Vector3.new(0, 60, 0))
        if (root.Position - aboveWorker.Position).Magnitude > 12 then
            local okFly, flyErr = pcall(function()
                flyTo(aboveWorker, 300, canContinueSubmergedTravel)
            end)
            if not okFly then Q.qlog("Submerged: lỗi bay tới phía trên NPC: " .. tostring(flyErr)) end
            task.wait(0.15)
        end

        if not canContinueSubmergedTravel() then
            submergedTravelBusy = false
            Q.qlog("Submerged: đã dừng di chuyển vì Auto Farm đã tắt")
            return true
        end

        root = getRoot()
        if not root then
            submergedTravelBusy = false
            return true
        end

        local nearWorker = CFrame.new(workerPos + Vector3.new(0, 3, 0))
        if (root.Position - nearWorker.Position).Magnitude > 10 then
            local okFly, flyErr = pcall(function()
                flyTo(nearWorker, 300, canContinueSubmergedTravel)
            end)
            if not okFly then Q.qlog("Submerged: lỗi bay áp sát NPC: " .. tostring(flyErr)) end
            task.wait(0.15)
        end

        root = getRoot()
        if not root then
            submergedTravelBusy = false
            return true
        end
        Q.qlog("Submerged: đã tới vị trí Submarine Worker")

        -- ƯU TIÊN RemoteFunction đúng theo đường dẫn trong bản Auto Travel:
        -- ReplicatedStorage.Modules.Net["RF/SubmarineWorkerSpeak"]
        -- Giữ thêm đường dẫn dự phòng cho các phiên bản game khác nhau.
        local function findSubmergedRemote()
            local modules = ReplicatedStorage:FindFirstChild("Modules")
            local net = modules and modules:FindFirstChild("Net")
            local rf = net and net:FindFirstChild("RF/SubmarineWorkerSpeak")
            if not rf and net then
                local nestedRF = net:FindFirstChild("RF")
                rf = nestedRF and nestedRF:FindFirstChild("SubmarineWorkerSpeak")
            end
            local rfFolder = ReplicatedStorage:FindFirstChild("RF")
            rf = rf or (rfFolder and rfFolder:FindFirstChild("SubmarineWorkerSpeak"))
            rf = rf or ReplicatedStorage:FindFirstChild("SubmarineWorkerSpeak")
            if rf and rf:IsA("RemoteFunction") then return rf end
            return nil
        end

        local remote = findSubmergedRemote()
        if remote then
            Q.qlog("Submerged: đang gọi RF/SubmarineWorkerSpeak")
            local callFinished, callOk, remoteResult = false, false, nil
            _G.MHSpawn(function()
                callOk, remoteResult = pcall(function()
                    return remote:InvokeServer("TravelToSubmergedIsland")
                end)
                callFinished = true
            end)

            local callDeadline = tick() + 5
            while not callFinished and tick() < callDeadline do task.wait(0.1) end
            if callFinished and callOk then
                Q.qlog("Submerged: remote đã phản hồi", tostring(remoteResult))
            elseif not callFinished then
                Q.qlog("Submerged: remote chưa phản hồi trong 5 giây; sẽ kiểm tra vị trí rồi thử hội thoại")
            else
                Q.qlog("Submerged: remote lỗi: " .. tostring(remoteResult))
            end

            -- Không xem remote trả về là thành công; chỉ xác nhận bằng tọa độ nhân vật.
            if waitForEntry(20) then return confirmedEntry() end
        else
            Q.qlog("Submerged: không tìm thấy RemoteFunction ở Modules.Net/RF; chuyển sang hội thoại NPC")
        end

        if accessDenied() then
            Q.qlog("Submerged: NPC từ chối chuyến đi; có thể chưa mở khóa hoặc chưa đủ điều kiện")
            if Q.SUB and Q.SUB.set then Q.SUB.set("NPC từ chối: kiểm tra điều kiện mở khóa đảo") end
            submergedTravelBusy = false
            submergedTravelLast = tick() + 20
            return true
        end

        -- DỰ PHÒNG: mở hội thoại và tự chọn Yes. Bấm được Yes vẫn chưa đủ;
        -- phải chờ xác nhận nhân vật thật sự ở dưới biển.
        worker = Q.submergedFindWorker() or worker
        if worker then
            Q.qlog("Submerged: đang thử hội thoại NPC làm phương án dự phòng")
            Q.submergedViaDialog(worker)
        else
            Q.qlog("Submerged: không thấy NPC để mở hội thoại dự phòng")
        end

        if isInsideSubmerged() or waitForEntry(10) then return confirmedEntry() end
        if accessDenied() then
            Q.qlog("Submerged: NPC từ chối chuyến đi; kiểm tra điều kiện mở khóa")
            if Q.SUB and Q.SUB.set then Q.SUB.set("NPC từ chối: kiểm tra điều kiện mở khóa đảo") end
            submergedTravelLast = tick() + 20
        else
            Q.qlog("Submerged: chưa xác nhận được vị trí dưới nước; sẽ thử lại")
            if Q.SUB and Q.SUB.set then Q.SUB.set("Chưa xuống được, đang thử lại...") end
            submergedTravelLast = tick() + 2
        end
        submergedTravelBusy = false
        return true
    end

    -- Sea 1 / Sea 2
    local commF = getCommF()
    if not commF then return false end

    -- SEA 1: xử lý entrance tới Skylands ở level 450-524 trước khi
    -- Auto Quest cố bay xa đến NPC. Dùng remote entrance theo từng khoảng level,
    -- giống logic trong snippet người dùng gửi; có cooldown để không spam remote.
    local levelNow = getLevel()
    if World1 and autoFarmEnabled and pos.Y > 800
        and levelNow >= 450 and levelNow <= 524
        and (hrp.Position - pos).Magnitude > 10000 then
        if tick() < (Q.skyEntranceWaitUntil or 0) then
            return true
        end

        local skyEntrance
        if levelNow <= 474 then
            skyEntrance = Vector3.new(-4607.82275, 872.54248, -1667.55688)
        else
            skyEntrance = Vector3.new(-7894.61768, 5547.14160, -380.29120)
        end

        Q.skyEntranceWaitUntil = tick() + 6
        Q.qlog("Sea 1 Skylands: requestEntrance cho level " .. tostring(levelNow), skyEntrance)
        local okEntrance, entranceErr = pcall(function()
            commF:InvokeServer("requestEntrance", skyEntrance)
        end)
        if not okEntrance then
            Q.qlog("Sea 1 Skylands: requestEntrance lỗi", tostring(entranceErr))
            Q.skyEntranceWaitUntil = tick() + 2
        end
        task.wait(0.35)
        return true
    end

    local entrance
    if World1 and pos.X > 50000 and hrp.Position.X < 50000 then
        if tick() < (Q.entranceWaitUntil or 0) then return true end   -- vừa gọi vào, đợi game dịch chuyển xuống
        if Q.flyToFishmanGate(hrp) then return true end   -- bay tới cổng vào + đứng chờ
        entrance = Vector3.new(61163.8515625, 5.342342376708252, 1819.7841796875)
    elseif World2 and pos.Z > 30000 and hrp.Position.Z < 30000 then
        -- Fallback for callers whose target is beyond the standard Sea 2 ship region.
        entrance = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125)
    end
    -- Đang ở Underwater City mà mục tiêu kế tiếp nằm bên ngoài (farm level xong ở đây) -> bay tới điểm thoát
    if not entrance and World1 and pos.X < 50000 and hrp.Position.X > 50000 then
        if Q.flyToUnderwaterExit(hrp) then return true end
    end
    if not entrance then return false end
    if tick() - (Q.lastEntrance or 0) < 6 then return false end
    Q.lastEntrance = tick()
    Q.qlog("requestEntrance ->", entrance)
    pcall(function() commF:InvokeServer("requestEntrance", entrance) end)
    if World1 then Q.entranceWaitUntil = tick() + Q.PORTAL_WAIT + 2 end   -- đợi xuống đảo dưới nước
    Q.gateArriveAt = nil   -- lần sau quay lại cổng sẽ đứng chờ lại từ đầu
    task.wait(1)
    return true
end

LocalPlayer.CharacterAdded:Connect(function()
    Q.lastCharSpawn = tick()
end)

function Q.isGuiShown(obj)
    local pg = LocalPlayer.PlayerGui
    local cur = obj
    while cur and cur ~= pg do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

-- (1) kiểu cũ
function Q.classicQuestVisible()
    local mainGui = LocalPlayer.PlayerGui:FindFirstChild("Main")
    local q = mainGui and mainGui:FindFirstChild("Quest")
    return (q and q.Visible) == true
end

function Q.findProgressIn(root)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text ~= "" then
            local c, t = string.match(d.Text, "^%s*%(?(%d+)%s*/%s*(%d+)%)?%s*$")
            if not c then c, t = string.match(d.Text, "(%d+)%s*/%s*(%d+)") end
            if c and t then return tonumber(c), tonumber(t) end
        end
    end
    return nil, nil
end

-- (2) quét tổng quát: nhãn đang hiện chứa "defeat" và tên quái (vd "Defeat 8 Living Zombies")
function Q.genericQuestScan(mobName)
    local lm = string.lower(mobName)
    for _, d in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text ~= "" then
            local t = string.lower(d.Text)
            if string.find(t, "defeat", 1, true) and string.find(t, lm, 1, true) and Q.isGuiShown(d) then
                -- tìm tiến độ x/y gần đó (lên tối đa 3 cấp cha)
                local c, tot
                local p = d.Parent
                for _ = 1, 3 do
                    if not p or p == LocalPlayer.PlayerGui then break end
                    c, tot = Q.findProgressIn(p)
                    if c then break end
                    p = p.Parent
                end
                return true, c, tot
            end
        end
    end
    return false
end

-- HasQuest: đang có quest hay không (kết hợp lớp 1 + lớp 2)
local function HasQuest()
    if Q.classicQuestVisible() then return true end
    return tick() - Q.genericSeenAt < 1.6
end

-- (3) đếm quái đã giết (chỉ đếm quái đúng tên quest, gần người chơi)
function Q.hookMob(mob)
    if Q.hookedMobs[mob] then return end
    local hum = mob:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    Q.hookedMobs[mob] = true
    hum.Died:Connect(function()
        if Q.currentQuestMobName and string.find(string.lower(mob.Name), string.lower(Q.currentQuestMobName), 1, true) then
            local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local mobHrp = mob:FindFirstChild("HumanoidRootPart")
            if myHrp and mobHrp and (myHrp.Position - mobHrp.Position).Magnitude < 250 then
                Q.killsSinceAccept += 1
            end
        end
    end)
end

_G.MHSpawn(function()
    local enemies = workspace:WaitForChild("Enemies", 30)
    if not enemies then return end
    for _, m in ipairs(enemies:GetChildren()) do Q.hookMob(m) end
    enemies.ChildAdded:Connect(function(m)
        task.wait(0.2)
        Q.hookMob(m)
    end)
end)

function Q.dumpQuestGui()
    local n = 0
    pcall(function()
        for _, d in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" and Q.isGuiShown(d) and n < 30 then
                n += 1
                Q.qlog("GUI:", d:GetFullName(), "=", d.Text)
            end
        end
    end)
end

-- Luồng nền: cập nhật trạng thái quest + tiến độ
_G.MHSpawn(function()
    local lastGeneric = 0
    while true do
        task.wait(0.2)
        if Q.classicQuestVisible() then
            Q.guiDetectionWorks = true
            Q.lastQuestSeen = tick()
            local mainGui = LocalPlayer.PlayerGui:FindFirstChild("Main")
            local q = mainGui and mainGui:FindFirstChild("Quest")
            if q then
                local c, t = Q.findProgressIn(q)
                if c then
                    if c ~= Q.lastCur or t ~= Q.lastTotal then Q.qlog("Tiến độ:", c .. "/" .. t) end
                    Q.lastCur, Q.lastTotal = c, t
                end
            end
        elseif Q.currentQuestMobName and tick() - lastGeneric >= 1 then
            lastGeneric = tick()
            local ok, found, c, t = pcall(Q.genericQuestScan, Q.currentQuestMobName)
            if ok and found then
                Q.genericSeenAt = tick()
                Q.guiDetectionWorks = true
                Q.lastQuestSeen = tick()
                if c then
                    if c ~= Q.lastCur or t ~= Q.lastTotal then Q.qlog("Tiến độ:", c .. "/" .. t) end
                    Q.lastCur, Q.lastTotal = c, t
                end
            end
        end
    end
end)

-- Trả về TRUE khi đang có quest (hoặc cho phép đi farm luôn),
-- FALSE khi đang trong quá trình nhận quest.
-- QUY TẮC: còn quest thì tuyệt đối không nhận lại / không huỷ -> làm xong mới nhận quest tiếp theo.
-- TỰ DÒ NPC NHẬN QUEST (đề phòng game đổi vị trí đảo/NPC như bản làm lại Sea 1):
--   0) Vị trí đã từng nhận quest thành công trong phiên này (Q.npcLearned) -> dùng trước.
--   1) NPC có Humanoid trong workspace.NPCs nằm sát toạ độ ghi sẵn -> lấy vị trí THẬT của NPC đó.
--   2) Toạ độ ghi sẵn đã lệch: xét NPC gần điểm hồi sinh quái nhất (cùng đảo), xoay vòng theo
--      số lần nhận quest thất bại để lần lượt thử từng NPC.
Q.npcLearned = Q.npcLearned or {}
Q.npcListAt, Q.npcList = 0, {}
Q.lastResolvedQuestNpc = nil

-- Khóa riêng cho từng nhiệm vụ: tránh dùng nhầm vị trí NPC của một quest khác
-- dù hai quest dùng chung QuestName nhưng khác level/mob.
function Q.makeQuestIdentity(questName, questLevel, mobName)
    return table.concat({
        string.lower(tostring(questName or "")),
        tostring(questLevel or ""),
        Q.normMob(mobName or "")
    }, ":")
end

local function compactNpcName(value)
    local n = string.lower(tostring(value or ""))
    n = string.gsub(n, "%s*%[.-%]%s*$", "")
    n = string.gsub(n, "[^%w]", "")
    -- Chuẩn hóa các kiểu tên thường gặp: CakeQuest1Giver, HauntedQuestGiver1...
    n = string.gsub(n, "questgiver%d*$", "")
    n = string.gsub(n, "giver%d*$", "")
    n = string.gsub(n, "quest%d+$", "quest")
    return n
end

local function isQuestNpcName(value)
    local n = string.lower(tostring(value or ""))
    return string.find(n, "quest", 1, true) ~= nil
        or string.find(n, "giver", 1, true) ~= nil
        or string.find(n, "adventurer", 1, true) ~= nil
end

function Q.questNpcCandidates(forceRefresh)
    if not forceRefresh and tick() - Q.npcListAt < 20 and #Q.npcList > 0 then
        return Q.npcList
    end

    Q.npcListAt = tick()
    local list = {}
    local folder = workspace:FindFirstChild("NPCs")
    if folder then
        for _, m in ipairs(folder:GetDescendants()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")
                and not Players:GetPlayerFromCharacter(m) then
                local ok, cf = pcall(function() return m:GetPivot() end)
                if ok and cf then
                    list[#list + 1] = {
                        model = m,
                        name = m.Name,
                        pos = cf.Position,
                        questLike = isQuestNpcName(m.Name),
                        compact = compactNpcName(m.Name),
                    }
                end
            end
        end
    end
    Q.npcList = list
    return list
end

function Q.ResolveQuestNpc(questName, hardPos, mobName, questLevel)
    if not hardPos then return nil end

    local identity = Q.makeQuestIdentity(questName, questLevel, mobName)
    local function usePosition(pos, sourceName, saveImmediately)
        if not pos then return hardPos end
        Q.lastResolvedQuestNpc = { key = identity, pos = pos, name = sourceName }
        if saveImmediately then Q.npcLearned[identity] = pos end
        return pos
    end

    -- 1) Vị trí từng nhận quest thành công cho đúng quest + level + mob.
    local learned = Q.npcLearned[identity]
    if learned and (learned - hardPos).Magnitude <= 2500 then
        Q.qlog("NPC quest: dùng vị trí đã xác nhận", tostring(questName), tostring(mobName))
        return usePosition(learned, "learned", false)
    end

    local list = Q.questNpcCandidates()
    if #list == 0 then
        Q.qlog("NPC quest: chưa tải được workspace.NPCs; dùng tọa độ quest đã cấu hình", tostring(questName))
        return usePosition(hardPos, "quest-data", false)
    end

    -- 2) Vị trí cấu hình trùng với NPC thật: đây là tín hiệu mạnh nhất.
    local direct, directDistance = nil, 85
    for _, c in ipairs(list) do
        local d = (c.pos - hardPos).Magnitude
        if d < directDistance then
            direct, directDistance = c, d
        end
    end
    if direct then
        Q.qlog("NPC quest: khớp tọa độ", direct.name, "|", tostring(questName), "| cách", math.floor(directDistance))
        return usePosition(direct.pos, direct.name, false)
    end

    -- 3) Tọa độ NPC đã thay đổi: so khớp tên QuestName với tên model NPC trước,
    -- rồi mới dùng khoảng cách để phân xử. Không xoay vòng qua NPC ngẫu nhiên.
    local expected = compactNpcName(questName)
    local named, namedScore = nil, -math.huge
    for _, c in ipairs(list) do
        local d = (c.pos - hardPos).Magnitude
        if d <= 2500 and expected ~= "" and c.compact ~= "" then
            local affinity = 0
            if c.compact == expected then
                affinity = 1200
            elseif string.find(c.compact, expected, 1, true)
                or (#c.compact >= 5 and string.find(expected, c.compact, 1, true)) then
                affinity = 850
            else
                local stem = string.gsub(expected, "quest$", "")
                if #stem >= 4 and string.find(c.compact, stem, 1, true) then
                    affinity = 520
                end
            end

            if affinity > 0 then
                local score = affinity - d * 0.22
                if score > namedScore then
                    named, namedScore = c, score
                end
            end
        end
    end
    if named and namedScore >= 250 then
        Q.qlog("NPC quest: khớp tên NPC", named.name, "|", tostring(questName), "| điểm", math.floor(namedScore))
        return usePosition(named.pos, named.name, false)
    end

    -- 4) Dự phòng cho NPC có tên chung như "Quest Giver": chỉ xét NPC có dấu hiệu
    -- nhận nhiệm vụ và nằm gần khu vực quest/spawn; loại merchant/trainer để tránh chọn nhầm.
    local anchor = nil
    if mobName then
        local okSpawn, spawnPos = pcall(GetQuestMobSpawn, mobName, hardPos)
        if okSpawn then anchor = spawnPos end
    end
    anchor = anchor or hardPos

    local generic, genericScore = nil, -math.huge
    for _, c in ipairs(list) do
        local raw = string.lower(tostring(c.name))
        local merchantLike = string.find(raw, "dealer", 1, true)
            or string.find(raw, "teacher", 1, true)
            or string.find(raw, "shop", 1, true)
            or string.find(raw, "trainer", 1, true)
        if c.questLike and not merchantLike then
            local dHard = (c.pos - hardPos).Magnitude
            local dAnchor = (c.pos - anchor).Magnitude
            if dHard <= 1400 and dAnchor <= 1600 then
                local score = 300 - dHard * 0.16 - dAnchor * 0.05
                if score > genericScore then
                    generic, genericScore = c, score
                end
            end
        end
    end
    if generic and genericScore > 0 then
        Q.qlog("NPC quest: dự phòng theo khu vực", generic.name, "|", tostring(questName))
        return usePosition(generic.pos, generic.name, false)
    end

    -- Không tìm được ứng viên đủ tin cậy thì dùng vị trí dữ liệu gốc; tuyệt đối không
    -- chọn NPC bất kỳ chỉ vì gần điểm spawn, tránh bay đến NPC shop/đào tạo.
    Q.qlog("NPC quest: không có ứng viên đáng tin; giữ tọa độ dự phòng", tostring(questName), tostring(mobName))
    return usePosition(hardPos, "quest-data", false)
end

local function claimQuestCore(questName, questLevel, mobName, questNpcPos)
    if not questName then return true end
    local key = Q.makeQuestIdentity(questName, questLevel, mobName)
    questNpcPos = Q.ResolveQuestNpc(questName, questNpcPos, mobName, questLevel)
    Q.currentQuestMobName = mobName

    -- 1) Đang có quest -> cứ đánh tiếp
    if HasQuest() then
        Q.lastQuestSeen = tick()
        if Q.acceptedQuestKey == nil then Q.acceptedQuestKey = key end
        Q.questAttempts = 0
        return true
    end

    -- 2) Vừa hồi sinh: chờ GUI load lại rồi mới kết luận
    if tick() - Q.lastCharSpawn < Q.QUEST_RESPAWN_WAIT then return false end

    -- 3a) Chế độ dự phòng (không đọc được GUI quest): dựa vào số quái đã giết từ lúc nhận quest
    if not Q.guiDetectionWorks and Q.questAcceptedAt > 0 then
        local need = Q.lastTotal or Q.QUEST_DEFAULT_KILLS
        if Q.killsSinceAccept < need and tick() - Q.questAcceptedAt < Q.QUEST_MAX_TIME then
            return true
        end
        Q.qlog("Chế độ dự phòng: đã giết", Q.killsSinceAccept .. "/" .. need, "-> nhận quest mới")
    end

    -- 3b) GUI quest vừa tắt: phân biệt "quest đã xong" và "GUI lỗi"
    if Q.guiDetectionWorks and Q.lastQuestSeen > 0 then
        local finished = (Q.lastCur == nil) or (Q.lastTotal == nil) or (Q.lastCur >= Q.lastTotal - 1)
        local waitNeeded = finished and Q.QUEST_HIDE_GRACE or Q.QUEST_LOST_WAIT
        if tick() - Q.lastQuestSeen < waitNeeded then
            return true
        end
    end

    if tick() < Q.questGiveUpUntil then return true end
    if tick() - Q.lastQuestAttempt < Q.QUEST_RETRY_DELAY then return false end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Sea 3 Submerged phải xử lý bước NPC trước; không phụ thuộc CommF_
    -- vì Auto Level cần vào đảo trước khi nhận quest ở dưới nước.
    if Q.enterIfNeeded(hrp, questNpcPos, "quest") then return false end

    local commF = getCommF()
    if not commF then return true end

    if (hrp.Position - questNpcPos).Magnitude > 30 then
        Q.qlog("Cần nhận quest mới -> bay tới NPC:", questName, questLevel)
        flyTo(CFrame.new(questNpcPos + Vector3.new(0, 5, 0)))
        if not autoFarmEnabled then return false end
        hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        if HasQuest() then Q.lastQuestSeen = tick(); return true end
    end

    Q.lastQuestAttempt = tick()
    Q.questAttempts += 1
    Q.qlog("StartQuest", questName, questLevel, "(lần " .. Q.questAttempts .. ")")
    local okCall = pcall(function() commF:InvokeServer("StartQuest", questName, questLevel) end)

    -- Chờ GUI quest hiện ra (tối đa 4s)
    local t0 = tick()
    while tick() - t0 < 4 and not HasQuest() do
        -- kiểm tra thêm bằng quét tổng quát cho giao diện mới
        local ok, found = pcall(Q.genericQuestScan, mobName)
        if ok and found then Q.genericSeenAt = tick(); Q.guiDetectionWorks = true end
        task.wait(0.15)
    end

    if HasQuest() then
        Q.questAttempts = 0
        Q.acceptedQuestKey = key
        Q.questAcceptedAt = tick()
        Q.killsSinceAccept = 0
        Q.lastQuestSeen = tick()
        Q.lastCur, Q.lastTotal = nil, nil
        cancelFarmTween()
        targetEnemy = nil
        Q.qlog("Đã nhận quest (thấy GUI), đi farm")
        -- Nhớ vị trí nhận quest thành công để lần sau bay thẳng tới đó (kể cả khi toạ độ ghi sẵn đã lệch)
        pcall(function()
            local resolved = Q.lastResolvedQuestNpc
            if resolved and resolved.key == key and resolved.pos then
                Q.npcLearned[key] = resolved.pos
            end
        end)
        return true
    end

    if okCall and not Q.guiDetectionWorks then
        -- Gọi remote không lỗi nhưng không đọc được GUI -> coi như đã nhận, dùng chế độ đếm quái
        Q.questAttempts = 0
        Q.acceptedQuestKey = key
        Q.questAcceptedAt = tick()
        Q.killsSinceAccept = 0
        Q.lastCur, Q.lastTotal = nil, nil
        cancelFarmTween()
        targetEnemy = nil
        Q.qlog("KHÔNG đọc được GUI quest -> dùng chế độ đếm quái. Gửi dòng GUI bên dưới cho dev:")
        Q.dumpQuestGui()
        return true
    end

    if Q.questAttempts >= 3 then
        Q.questAttempts = 0
        Q.questGiveUpUntil = tick() + 20
        Q.qlog("Nhận quest thất bại 3 lần, bỏ qua 20s để farm")
        return true
    end
    return false
end

local function ClaimQuest()
    if not autoQuestEnabled then return true end
    local questName, questLevel, mobName, questNpcPos = GetQuestData()
    return claimQuestCore(questName, questLevel, mobName, questNpcPos)
end

-- HÀM TỰ ĐỘNG NHẬN QUEST TẠI ĐẢO XƯƠNG (SEA 3)
local function ClaimBonesQuest()
    if not autoQuestEnabled or not World3 then return true end
    local questName, questLevel, mobName, questNpcPos = GetHauntedQuestData()
    return claimQuestCore(questName, questLevel, mobName, questNpcPos)
end

-- NHIỆM VỤ ĐẢO BÁNH (CAKE LAND) DÙNG KHI FARM CAKE PRINCE
-- Quái Cookie Crafter / Cake Guard / Baking Staff / Head Baker đều được tính vào bộ đếm gọi Cake Prince.
function Q.GetCakeQuestData()
    local level = getLevel()
    if level < 2225 then
        return "CakeQuest1", 1, "Cookie Crafter", Vector3.new(-2021.32, 37.80, -12028.73), Vector3.new(-2374.14, 37.80, -12125.31)
    elseif level < 2250 then
        return "CakeQuest1", 2, "Cake Guard", Vector3.new(-2021.32, 37.80, -12028.73), Vector3.new(-1598.31, 43.77, -12244.58)
    elseif level < 2275 then
        return "CakeQuest2", 1, "Baking Staff", Vector3.new(-1927.92, 37.80, -12842.54), Vector3.new(-1887.80, 77.62, -12998.35)
    else
        return "CakeQuest2", 2, "Head Baker", Vector3.new(-1927.92, 37.80, -12842.54), Vector3.new(-2216.19, 82.88, -12869.29)
    end
end

function Q.ClaimCakeQuest()
    if not autoQuestEnabled or not World3 then return true end
    local questName, questLevel, mobName, questNpcPos = Q.GetCakeQuestData()
    return claimQuestCore(questName, questLevel, mobName, questNpcPos)
end

-- UI HELPERS & THEME CONFIG (MINH HUB STYLE)
local BANANA_YELLOW       = Color3.fromRGB(64, 140, 255)  -- xanh dương (điểm nhấn)
local BANANA_DARK         = Color3.fromRGB(70, 74, 86)    -- viền cửa sổ
local BANANA_BG           = Color3.fromRGB(22, 24, 30)
local BANANA_SIDEBAR      = Color3.fromRGB(14, 15, 19)
local BANANA_CARD         = Color3.fromRGB(44, 46, 54)
local BANANA_CARD_BORDER  = Color3.fromRGB(72, 76, 88)
local BANANA_TEXT_ON      = Color3.fromRGB(255, 255, 255)

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
    return corner
end

local function addStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Parent = parent
    return stroke
end

local function getTargetParent()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    local okCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if okCore and coreGui then return coreGui end
    return LocalPlayer:WaitForChild("PlayerGui", 10) or LocalPlayer:WaitForChild("PlayerGui")
end

local uiContainer = getTargetParent()

pcall(function()
    for _, oldName in ipairs({"MinhHubBloxFruits", "BananaCatHub", "RedzHubBloxFruits"}) do
        if uiContainer:FindFirstChild(oldName) then
            uiContainer[oldName]:Destroy()
        end
    end
end)

_G.MinhHubLoad(28, "Creating the menu interface...")
-- TẠO UI GIAO DIỆN MENU
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MinhHubBloxFruits"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999999
screenGui.Enabled = false  -- ẩn menu cho tới khi load script xong
_G.MinhHubMenuGui = screenGui

pcall(function()
    if syn and type(syn) == "table" and syn.protect_gui then
        syn.protect_gui(screenGui)
    end
end)
screenGui.Parent = uiContainer

local toggleBtn = Instance.new("ImageButton")
toggleBtn.Name = "MinhHubOpenButton"
toggleBtn.Size = UDim2.new(0, 56, 0, 56)
toggleBtn.Position = UDim2.new(0, 20, 0.15, 0)
toggleBtn.BackgroundColor3 = BANANA_SIDEBAR
toggleBtn.Image = ""
toggleBtn.ImageColor3 = BANANA_YELLOW
toggleBtn.Parent = screenGui
addCorner(toggleBtn, 28)
addStroke(toggleBtn, BANANA_YELLOW, 2)
do
    local bananaIcon = Instance.new("TextLabel")
    bananaIcon.Size = UDim2.new(1, 0, 1, 0)
    bananaIcon.BackgroundTransparency = 1
    bananaIcon.Text = "M"
    bananaIcon.TextColor3 = BANANA_YELLOW
    bananaIcon.TextSize = 28
    bananaIcon.Font = Enum.Font.GothamBlack
    bananaIcon.Active = false
    bananaIcon.Parent = toggleBtn
end

local MH = { W = 520, H = 390, HEAD = 34, SIDE = 165 }

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, MH.W, 0, MH.H)
mainFrame.Position = UDim2.new(0.5, -MH.W / 2, 0.5, -MH.H / 2)
mainFrame.BackgroundColor3 = BANANA_BG
mainFrame.BackgroundTransparency = 0.12
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Visible = true
mainFrame.Parent = screenGui
addCorner(mainFrame, 12)
do
    local winStroke = addStroke(mainFrame, BANANA_DARK, 1)
    winStroke.Transparency = 0.35

    local menuScale = Instance.new("UIScale")
    menuScale.Name = "MenuScale"
    menuScale.Scale = 1
    menuScale.Parent = mainFrame
end

-- Thanh tiêu đề: tên hub nhỏ bên trái, 3 nút cửa sổ bên phải
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, MH.HEAD)
header.BackgroundColor3 = BANANA_SIDEBAR
header.BackgroundTransparency = 0.35
header.BorderSizePixel = 0
header.Parent = mainFrame

do
    local headLine = Instance.new("Frame")
    headLine.Name = "HeaderLine"
    headLine.Size = UDim2.new(1, 0, 0, 1)
    headLine.Position = UDim2.new(0, 0, 1, -1)
    headLine.BackgroundColor3 = BANANA_CARD_BORDER
    headLine.BackgroundTransparency = 0.5
    headLine.BorderSizePixel = 0
    headLine.Parent = header
end

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, -150, 1, 0)
headerTitle.Position = UDim2.new(0, 12, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "Minh Hub Premium  <font color=\"#8A8F9E\">|  Blox Fruits  |</font>"
headerTitle.RichText = true
headerTitle.TextColor3 = Color3.fromRGB(235, 237, 245)
headerTitle.TextSize = 12
headerTitle.Font = Enum.Font.GothamMedium
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = header

function MH.winBtn(text, xOff, size)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 34, 1, 0)
    b.Position = UDim2.new(1, xOff, 0, 0)
    b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    b.BackgroundTransparency = 1
    b.Text = text
    b.TextColor3 = Color3.fromRGB(215, 218, 228)
    b.TextSize = size or 13
    b.Font = Enum.Font.GothamMedium
    b.AutoButtonColor = false
    b.Parent = header
    b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.88 end)
    b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
    return b
end
local closeBtn    = MH.winBtn("✕", -34, 12)
MH.maxBtn = MH.winBtn("▢", -68, 14)
local minimizeBtn = MH.winBtn("—", -102, 13)

-- Thanh bên: logo lớn ở trên, danh sách tab bên dưới
local sidebar = Instance.new("ScrollingFrame")   -- cuộn được: nhiều tab không bị cắt mất
sidebar.ScrollBarThickness = 0
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, MH.SIDE, 1, -MH.HEAD)
sidebar.Position = UDim2.new(0, 0, 0, MH.HEAD)
sidebar.BackgroundColor3 = BANANA_SIDEBAR
sidebar.BackgroundTransparency = 1
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame

do
    local sideLine = Instance.new("Frame")
    sideLine.Name = "SidebarLine"
    sideLine.Size = UDim2.new(0, 1, 1, -MH.HEAD)
    sideLine.Position = UDim2.new(0, MH.SIDE, 0, MH.HEAD)
    sideLine.BackgroundColor3 = BANANA_CARD_BORDER
    sideLine.BackgroundTransparency = 0.6
    sideLine.BorderSizePixel = 0
    sideLine.Parent = mainFrame -- KHÔNG đặt trong sidebar: sẽ bị UIListLayout xếp và đẩy hết tab ra ngoài
end

local sidebarList = Instance.new("UIListLayout")
sidebarList.Parent = sidebar
sidebarList.SortOrder = Enum.SortOrder.LayoutOrder
sidebarList.Padding = UDim.new(0, 4)
sidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local sidebarPadding = Instance.new("UIPadding")
sidebarPadding.PaddingTop = UDim.new(0, 6)
sidebarPadding.Parent = sidebar

do
    -- Logo lớn (chữ M cách điệu trong khung thoi) ở đầu thanh bên
    local logoWrap = Instance.new("Frame")
    logoWrap.Name = "LogoWrap"
    logoWrap.Size = UDim2.new(1, 0, 0, 100)
    logoWrap.LayoutOrder = -100
    logoWrap.BackgroundTransparency = 1
    logoWrap.Parent = sidebar

    local diamond = Instance.new("Frame")
    diamond.AnchorPoint = Vector2.new(0.5, 0.5)
    diamond.Position = UDim2.new(0.5, 0, 0.5, 0)
    diamond.Size = UDim2.new(0, 62, 0, 62)
    diamond.Rotation = 45
    diamond.BackgroundTransparency = 1
    diamond.Parent = logoWrap
    local dStroke = addStroke(diamond, BANANA_YELLOW, 2)
    dStroke.Transparency = 0.1
    addCorner(diamond, 6)

    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.new(1, 0, 1, 0)
    logoText.BackgroundTransparency = 1
    logoText.Text = "M"
    logoText.TextSize = 46
    logoText.Font = Enum.Font.GothamBlack
    logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
    logoText.Parent = logoWrap
    local lg = Instance.new("UIGradient")
    lg.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), BANANA_YELLOW)
    lg.Rotation = 90
    lg.Parent = logoText
end

-- Tiêu đề trang lớn + vùng nội dung bên phải
local pageTitle = Instance.new("TextLabel")
pageTitle.Name = "PageTitle"
pageTitle.Size = UDim2.new(1, -(MH.SIDE + 30), 0, 26)
pageTitle.Position = UDim2.new(0, MH.SIDE + 16, 0, MH.HEAD + 8)
pageTitle.BackgroundTransparency = 1
pageTitle.Text = "Farm"
pageTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
pageTitle.TextSize = 20
pageTitle.Font = Enum.Font.GothamBold
pageTitle.TextXAlignment = Enum.TextXAlignment.Left
pageTitle.Parent = mainFrame

do
    local titleUnderline = Instance.new("Frame")
    titleUnderline.Name = "TitleUnderline"
    titleUnderline.Size = UDim2.new(0, 0, 0, 0)
    titleUnderline.BackgroundTransparency = 1
    titleUnderline.Visible = false
    titleUnderline.Parent = mainFrame
end

local pagesFolder = Instance.new("Frame")
pagesFolder.Name = "Pages"
pagesFolder.Size = UDim2.new(1, -(MH.SIDE + 24), 1, -(MH.HEAD + 54))
pagesFolder.Position = UDim2.new(0, MH.SIDE + 12, 0, MH.HEAD + 42)
pagesFolder.BackgroundTransparency = 1
pagesFolder.Parent = mainFrame

local tabs = {}
local function createTab(tabName, iconText, isDefault)
    local tabLabel = ({Farm = "Main", Boss = "Multi Farm", Gacha = "Items", Config = "Farm Settings"})[tabName] or tabName
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, -20, 0, 28)
    tabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    tabBtn.BackgroundTransparency = isDefault and 0.9 or 1
    tabBtn.AutoButtonColor = false
    tabBtn.Text = tabLabel
    tabBtn.TextColor3 = isDefault and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(165, 168, 180)
    tabBtn.Font = Enum.Font.GothamMedium
    tabBtn.TextSize = 12
    tabBtn.TextXAlignment = Enum.TextXAlignment.Left
    tabBtn.Parent = sidebar
    addCorner(tabBtn, 6)

    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingLeft = UDim.new(0, 34)
    tabPad.Parent = tabBtn

    -- biểu tượng đơn sắc bên trái tên tab
    do
        local iconMap = {Farm = "⚔", Boss = "♛", Raid = "☄", Gacha = "✦", Shop = "⛁", Config = "⚙", ESP = "◉", Status = "▤"}
        local ic = Instance.new("TextLabel")
        ic.Size = UDim2.new(0, 22, 1, 0)
        ic.Position = UDim2.new(0, -26, 0, 0)
        ic.BackgroundTransparency = 1
        ic.Text = iconMap[tabName] or "▪"
        ic.TextColor3 = Color3.fromRGB(200, 204, 216)
        ic.TextSize = 14
        ic.Font = Enum.Font.GothamBold
        ic.Active = false
        ic.Parent = tabBtn
    end

    -- thanh vàng nhỏ bên trái tab đang chọn
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 0, 16)
    indicator.AnchorPoint = Vector2.new(0, 0.5)
    indicator.Position = UDim2.new(0, -10, 0.5, 0)
    indicator.BackgroundColor3 = BANANA_YELLOW
    indicator.BorderSizePixel = 0
    indicator.Visible = isDefault
    indicator.Parent = tabBtn
    addCorner(indicator, 2)

    local page = Instance.new("ScrollingFrame")
    page.Name = tabName .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Color3.fromRGB(120, 126, 142)
    -- Tự tăng vùng cuộn theo toàn bộ các thẻ; nếu không, các mục ở cuối Shop
    -- (Electric Claw, Dragon Talon, Godhuman, Sanguine Art) sẽ nằm ngoài vùng nhìn thấy.
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.Visible = isDefault
    page.Parent = pagesFolder

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Parent = page
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 5)
    pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingRight = UDim.new(0, 8)
    pagePadding.Parent = page

    if isDefault then pageTitle.Text = tabLabel end

    tabBtn.MouseEnter:Connect(function()
        if not page.Visible then
            TweenService:Create(tabBtn, TweenInfo.new(0.12), {TextColor3 = Color3.fromRGB(235, 237, 245), BackgroundTransparency = 0.95}):Play()
        end
    end)
    tabBtn.MouseLeave:Connect(function()
        if not page.Visible then
            TweenService:Create(tabBtn, TweenInfo.new(0.12), {TextColor3 = Color3.fromRGB(165, 168, 180), BackgroundTransparency = 1}):Play()
        end
    end)

    tabBtn.MouseButton1Click:Connect(function()
        if page.Visible then return end
        for _, data in pairs(tabs) do
            data.Page.Visible = false
            data.Indicator.Visible = false
            data.Button.TextColor3 = Color3.fromRGB(165, 168, 180)
            data.Button.BackgroundTransparency = 1
        end
        page.Position = UDim2.new(0, 16, 0, 0)
        page.Visible = true
        TweenService:Create(page, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
        indicator.Size = UDim2.new(0, 3, 0, 4)
        indicator.Visible = true
        TweenService:Create(indicator, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 3, 0, 16)}):Play()
        tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabBtn.BackgroundTransparency = 0.9
        pageTitle.Text = tabLabel
    end)

    tabs[tabName] = {Button = tabBtn, Page = page, Indicator = indicator}
    return page
end

local farmPage     = createTab("Farm", "⚔️", true)
local bossPage     = createTab("Boss", "👑", false)
local raidPage     = createTab("Raid", "🔥", false)
local gachaPage    = createTab("Gacha", "🎲", false)
local shopPage     = createTab("Shop", "🛒", false)
local settingsPage = createTab("Config", "⚙️", false)

-- =========================================================
-- VIETNAMESE / ENGLISH UI LANGUAGE
-- Dịch văn bản giao diện; không thay đổi logic farm hoặc dữ liệu game.
-- =========================================================
do
    local exactPairs = {
        {"Main", "Trang chính"},
        {"Farm", "Cày cuốc"},
        {"Multi Farm", "Farm nhiều mục tiêu"},
        {"Items", "Vật phẩm"},
        {"Farm Settings", "Cài đặt Farm"},
        {"Config", "Cài đặt"},
        {"Raid", "Đột kích"},
        {"Shop", "Cửa hàng"},
        {"Status", "Trạng thái"},
        {"Weapon & Distance", "Vũ khí & Khoảng cách"},
        {"Fast Attack & Bring Mob", "Đánh nhanh & Gom quái"},
        {"Haki & Race", "Haki & Tộc"},
        {"Misc", "Khác"},
        {"Redeem Code", "Đổi Code"},
        {"Server Stats", "Thống kê máy chủ"},
        {"Server Events", "Sự kiện máy chủ"},
        {"Local Stats", "Thống kê nhân vật"},
        {"Server Time", "Thời gian máy chủ"},
        {"Players", "Người chơi"},
        {"Sea & Night", "Biển & Ban đêm"},
        {"Moon", "Mặt trăng"},
        {"Event Islands (Mirage / Prehistoric / Kitsune)", "Đảo sự kiện (Mirage / Prehistoric / Kitsune)"},
        {"Fruits on the ground", "Trái ác quỷ trên đất"},
        {"Spawned Bosses", "Boss đang xuất hiện"},
        {"Elite Progress", "Tiến độ Elite"},
        {"Character (Level / Beli / Fragments)", "Nhân vật (Level / Beli / Fragments)"},
        {"Auto Farm", "Tự động Farm"},
        {"Auto Quest", "Tự động nhận nhiệm vụ"},
        {"Auto Farm Material", "Tự động farm nguyên liệu"},
        {"Auto Farm Boss", "Tự động farm Boss"},
        {"Auto Elite Hunter", "Săn Elite tự động"},
        {"Auto Buy Chip", "Tự động mua Chip"},
        {"Auto Start Raid", "Tự động bắt đầu Raid"},
        {"Auto Raid", "Tự động Raid"},
        {"Raid Kill Aura", "Aura diệt quái Raid"},
        {"Auto Law Raid", "Tự động Raid Law"},
        {"Auto Farm Chest", "Tự động farm rương"},
        {"Auto Random Bones", "Tự động đổi Bones"},
        {"Auto Store Fruit", "Tự động cất Trái"},
        {"Auto Collect Fruit", "Tự động nhặt Trái"},
        {"Auto Buy Random Fruit", "Tự động mua Trái ngẫu nhiên"},
        {"Bring Mob", "Gom quái"},
        {"Fast Attack", "Đánh nhanh"},
        {"Auto Buso Haki", "Tự động Haki Vũ Trang"},
        {"Auto Observation Haki", "Tự động Haki Quan Sát"},
        {"Remove Fog", "Xóa sương mù"},
        {"Auto Race V3", "Tự động Tộc V3"},
        {"Auto Race V4", "Tự động Tộc V4"},
        {"Anti AFK", "Chống AFK"},
        {"Fast Attack Players", "Đánh nhanh người chơi"},
        {"Auto Fast Attack", "Tự động đánh nhanh"},
        {"ESP Player", "ESP người chơi"},
        {"ESP Fruit", "ESP Trái ác quỷ"},
        {"ESP Island", "ESP đảo"},
        {"ESP Highlight", "ESP viền sáng"},
        {"Enter code (optional)", "Nhập code (tuỳ chọn)"},
        {"Leave blank = redeem all", "Để trống = nhập tất cả"},
        {"Click to redeem codes", "Nhấn Click để nhập code"},
        {"Search section or Func...", "Tìm mục hoặc chức năng..."},
        {"Disabled", "Đang tắt"},
        {"Enabled", "Đang bật"},
        {"Checking...", "Đang kiểm tra..."},
        {"Loading...", "Đang tải..."},
        {"Starting...", "Khởi động..."},
        {"Complete!", "Hoàn tất!"},

        {"Remove Fog", "Xóa sương mù"},
        {"Auto Select Team", "Tự động chọn phe"},
        {"🌐 Interface Language", "🌐 Language / Ngôn ngữ"},
        {"🍎 Stock: Regular Shop", "🍎 Stock: Shop Thường"},
        {"🍎 Regular Shop", "🍎 Shop Thường"},
        {"🏝 Mirage Island", "🏝 Đảo Bí Ẩn"},
        {"🏝️ Stock: Mirage Island", "🏝️ Stock: Đảo Bí Ẩn (Mirage)"},
        {"Farm Height (Flight Altitude)", "Độ cao Farm (Bay cao)"},
        {"Distance Farm Nearby Mobs", "Khoảng cách Farm quái gần"},
        {"Select Team", "Chọn phe / Select Team"},
        {"Select multiple stats (click to toggle)", "Chọn nhiều chỉ số (bấm để chọn/bỏ chọn)"},
        {"Points per allocation:", "Số điểm mỗi lần:"},
        {"Enter point amount", "Nhập số điểm"},
        {"Status: Ready", "Trạng thái: Sẵn sàng"},
        {"Status: Select at least one stat", "Trạng thái: Hãy chọn ít nhất 1 chỉ số"},
        {"Status: CommF_ not found", "Trạng thái: Không tìm thấy CommF_"},
        {"ADD SELECTED STATS", "CỘNG ĐIỂM ĐÃ CHỌN"},
        {"🥋 MELEE FIGHTING STYLE SHOP", "🥋 MUA VÕ CẬN CHIẾN"},
        {"Farming: ...", "Đang farm: ..."},
        {"Reading team information...", "Đang đọc thông tin phe..."},
        {"Current: ", "Hiện tại: "},
        {"  |  Target: ", "  |  Mục tiêu: "},
        {"\nStatus: ", "\nTrạng thái: "},
        {"No event islands currently exist", "Không có đảo sự kiện nào đang tồn tại"},
        {"No fruits on the ground", "Không có trái nào trên đất"},
        {"No bosses currently spawned", "Chưa có boss nào xuất hiện"},
        {"No data yet (open the Boss tab and wait a few seconds)", "Chưa có dữ liệu (mở tab Boss / đợi vài giây)"},
        {"Only available in Sea 3", "Chỉ có ở Sea 3"},
        {"Unable to read data", "Không đọc được"},
        {"FULL MOON", "TRĂNG TRÒN"},
        {"Night", "Ban đêm"},
        {"Day", "Ban ngày"},
        {"Unknown", "Không rõ"},
        {"Hunted: ", "Đã săn: "},
        {" fruits: ", " trái: "},
        {" / 500 mobs", " / 500 quái"},
        {"Server uptime", "thời gian server đã chạy"},
        {"Pirates", "Hải tặc"},
        {"Marines", "Hải quân"},
        {"Fighting Dough King", "Đang đánh Dough King"},
        {"Dough King defeated ✅", "Đã hạ Dough King ✅"},
        {"Farming Cake Land (counting 500 mobs)", "Farm Cake Land (đếm 500 quái)"},
        {"Missing God's Chalice -> running Elite Hunter to obtain one", "Thiếu God's Chalice -> đang chạy Elite Hunter để kiếm"},
        {"Exchanging for Sweet Chalice at Sweet Crafter", "Đang đổi Sweet Chalice ở Sweet Crafter"},
        {"Talking to drip_mama to summon Dough King", "Đang nói chuyện với drip_mama để gọi Dough King"},
        {"Sweet Crafter NPC not found (Chocolate Land)", "Không tìm thấy NPC Sweet Crafter (Chocolate Land)"},
        {"drip_mama NPC not found", "Không thấy NPC drip_mama"},
        {"Special Microchip received", "Đã nhận Special Microchip"},
        {"No Special Microchip", "Chưa có Special Microchip"},
        {"Reached the Raid room", "Đã tới phòng Raid"},
        {"Raid started", "Raid đã bắt đầu"},
        {"Raid completed", "Raid hoàn thành"},
        {"Fighting Tyrant of the Skies", "Đang đánh Tyrant of the Skies"},
        {"Tyrant of the Skies defeated", "Đã hạ Tyrant of the Skies"},
        {"Yielding to Raid / fruit collection", "Đang nhường cho Raid / nhặt trái"},
        {"Fighting pirates", "Đang đánh hải tặc"},
    }

    -- Các cặp bên dưới được thay trong câu dài (theo thứ tự dài nhất trước).
    local phrasePairs = {
        {"Blox Fruits • Đang tải script...", "Blox Fruits • Loading script..."},
        {"Vũ khí: ", "Weapon: "},
        {"Đang tải bộ bay ổn định...", "Loading stable flight system..."},
        {"Đang tải thông tin người chơi...", "Loading player information..."},
        {"Đang tải dữ liệu Auto Quest...", "Loading Auto Quest data..."},
        {"Đang tải Redeem Code...", "Loading Redeem Code..."},
        {"Đang tạo giao diện menu...", "Creating the menu interface..."},
        {"Đang tải tab ESP...", "Loading the ESP tab..."},
        {"Đang tải tab Status...", "Loading the Status tab..."},
        {"Tự động farm mục tiêu đã chọn", "Automatically farm the selected target"},
        {"Tự động nhận nhiệm vụ chuẩn theo cấp độ (Gồm cả Đảo Xương)", "Automatically accept level-appropriate quests (including Haunted Castle)"},
        {"Bay đến và diệt quái rớt nguyên liệu chọn", "Fly to and defeat mobs that drop the selected material"},
        {"Tự động bay đến vị trí & hạ gục Boss đã chọn", "Automatically travel to and defeat the selected Boss"},
        {"Tự nhận nhiệm vụ Elite & hạ Diablo / Urban / Deandre (Sea 3)", "Automatically accept Elite quests and defeat Diablo / Urban / Deandre (Sea 3)"},
        {"Tự động mua Chip Raid đã chọn", "Automatically buy the selected Raid Chip"},
        {"Tự động nhấn nút bắt đầu phòng Raid", "Automatically press the Raid start button"},
        {"Tự động bay diệt quái & bay qua các đảo Raid", "Automatically fly to defeat mobs and travel between Raid islands"},
        {"Đảo 4 & 5: gom toàn bộ quái Raid rồi RESET (giết) hết cùng lúc", "Islands 4 & 5: gather all Raid mobs and reset (kill) them together"},
        {"Tự động đánh Boss Order (Law)", "Automatically fight the Order (Law) Boss"},
        {"Nhặt rương khi các tác vụ ưu tiên cao hơn đang rảnh; tự tiếp tục sau khi farm/Raid xong", "Collect chests when higher-priority tasks are idle; resume after farming/Raid finishes"},
        {"Tự động dùng 50 Bones đổi quà ngẫu nhiên tại Death King", "Automatically spend 50 Bones for a random reward at Death King"},
        {"Tự động cất tất cả Trái Ác Quỷ trong kho đồ (Backpack) vào rương", "Automatically store all Devil Fruits from the Backpack into the chest"},
        {"Tự động bay tới nhặt Trái Ác Quỷ rơi trên map (nên bật kèm Auto Store Fruit)", "Automatically fly to collect dropped Devil Fruits (use with Auto Store Fruit)"},
        {"Thử mua từ xa; nếu server từ chối sẽ tự bay tới Zioles bấm mua. Game giới hạn 2 giờ/lần, cần Lv50+ - nên bật kèm Auto Store Fruit", "Try remote purchase; if rejected, fly to Zioles and buy. Limited to once every 2 hours, Lv. 50+ required; use with Auto Store Fruit"},
        {"Gom quái xung quanh về 1 điểm", "Gather nearby mobs into one spot"},
        {"Đánh siêu nhanh không delay cho cả Cận chiến, Kiếm & Trái ác quỷ", "Very fast, no-delay attacks for Melee, Sword, and Blox Fruit"},
        {"Tự động kích hoạt Haki Vũ Trang", "Automatically activate Armament Haki"},
        {"Tự động bật Haki Quan Sát / Instinct (Phím E)", "Automatically activate Observation Haki / Instinct (E key)"},
        {"Giảm Fog/Atmosphere để nhìn xa rõ hơn", "Reduce Fog/Atmosphere for clearer long-distance vision"},
        {"Tự động dùng skill Tộc V3 (Phím T)", "Automatically use the Race V3 skill (T key)"},
        {"Tự động bật Thức Tỉnh Tộc V4 (Phím Y)", "Automatically activate Race V4 awakening (Y key)"},
        {"Tự động chống văng game (Disconnect) khi treo máy", "Automatically prevent AFK disconnections"},
        {"Đánh nhanh cả người chơi gần đó, kết hợp cùng lúc với Fast Attack quái", "Fast-attack nearby players alongside mobs"},
        {"Tự bật Fast Attack khi bắt đầu farm và tự đánh khi có mục tiêu trong tầm", "Enable Fast Attack while farming and automatically attack targets in range"},
        {"Cộng điểm vào Demon Fruit", "Add points to Blox Fruit"},
        {"Cộng điểm vào Melee", "Add points to Melee"},
        {"Cộng điểm vào Defense", "Add points to Defense"},
        {"Cộng điểm vào Sword", "Add points to Sword"},
        {"Cộng điểm vào Gun", "Add points to Gun"},
        {"Nhập code (tuỳ chọn)", "Enter code (optional)"},
        {"Để trống = nhập tất cả", "Leave blank = redeem all"},
        {"Nhấn Click để nhập code", "Click to redeem codes"},
        {"Không có đảo sự kiện nào đang tồn tại", "No event islands currently exist"},
        {"Không có trái nào trên đất", "No fruits on the ground"},
        {"Chưa có boss nào xuất hiện", "No bosses currently spawned"},
        {"Chưa có dữ liệu", "No data yet"},
        {"Đang quét...", "Scanning..."},
        {"Đang tải...", "Loading..."},
        {"Đang kiểm tra...", "Checking..."},
        {"Đang tắt", "Disabled"},
        {"Đang bật", "Enabled"},
        {"Đang bay tới:", "Flying to:"},
        {"Mục tiêu: chưa có (đang tìm quái / di chuyển)", "Target: none (searching for mobs / moving)"},
        {"(thời gian server đã chạy)", "(server uptime)"},
        {"Đang nhập", "Redeeming"},
        {"Xong: đã gửi", "Done: submitted"},
        {"Xem kết quả ở F9", "check results in F9"},
        {"Xem F9 để biết code nào nhận được.", "Check F9 to see which codes were accepted."},
        {"Đã nhận quest", "Quest accepted"},
        {"Nhận quest thất bại", "Quest acceptance failed"},
        {"Tự động", "Automatically"},

        {"Trạng thái Cake Prince:", "Cake Prince Status:"},
        {"Cake Prince đã xuất hiện", "Cake Prince has appeared"},
        {"(lần ", "(attempt "},
        {"Cake Prince còn lại: ", "Cake Prince remaining: "},
        {"Đang kiểm tra cổng Cake Prince:", "Checking the Cake Prince portal:"},
        {"Đang farm mục tiêu:", "Farming target:"},
        {"Trái Ác Quỷ", "Devil Fruit"},
        {"Đảo Bí Ẩn", "Mirage Island"},
        {"Đang nhặt trái ác quỷ", "Collecting Devil Fruits"},
        {"Đang đánh Pirate Raid", "Fighting the Pirate Raid"},
        {"Đang chạy Raid", "Running the Raid"},
        {"Đang farm Chest", "Collecting chests"},
        {"Không farm gì (tất cả đang tắt)", "No farming task running (all features are disabled)"},
        {"Đang farm:", "Farming:"},
        {"đang tìm quái", "searching for mobs"},
        {"đang bay tới", "flying to"},
        {"chờ boss xuất hiện", "waiting for the boss to spawn"},
        {"đang thử lại", "retrying"},
        {"đang kiểm tra", "checking"},
        {"Đã qua cổng", "Passed through the portal"},
        {"đang chờ tải/tìm boss", "waiting for the area to load / searching for the boss"},
        {"Đã xác nhận cổng Cake Prince mở — đang bay đến cổng...", "Cake Prince portal confirmed open — flying to the portal..."},
        {"Cổng không phản hồi sau 40s — đang kiểm tra / mở cổng lại...", "Portal did not respond after 40s — checking / reopening the portal..."},
        {"Đã gửi xác nhận mở cổng; chưa thấy trạng thái cổng mở nên tiếp tục farm Cake Land và kiểm tra lại...", "Portal-open request sent; the portal is not confirmed open yet, so continuing to farm Cake Land and checking again..."},
        {"Gửi lệnh mở cổng thất bại; tiếp tục farm Cake Land và sẽ thử lại.", "Failed to request portal opening; continuing to farm Cake Land and retrying."},
        {"Đủ điều kiện 500 quái — đang mở/xác minh cổng; chưa xác nhận thì tiếp tục farm Cake Land.", "500-mob requirement met — opening/verifying the portal; continue farming Cake Land until it is confirmed open."},
        {"Đã đủ điều kiện nhưng cổng chưa xác nhận mở — đang thử mở cổng...", "Requirements met but the portal is not confirmed open — trying to open it..."},
        {"Đã quay lại khu Cake Prince — đang tìm boss để đánh tiếp...", "Returned to the Cake Prince area — searching for the boss to continue..."},
        {"Đã qua cổng — đang chờ tải/tìm boss Cake Prince...", "Passed through the portal — waiting for the Cake Prince area to load / searching for the boss..."},
        {"Đã chết trong khu boss — hồi sinh xong sẽ quay lại cổng Cake Prince...", "Died in the boss area — returning to the Cake Prince portal after respawning..."},
        {"Đã chết khi farm Cake Land — hồi sinh xong tiếp tục farm và kiểm tra cổng.", "Died while farming Cake Land — will resume farming and check the portal after respawning."},
        {"Đang chui vào cổng Cake Prince", "Entering the Cake Prince portal"},
        {"chờ boss xuất hiện", "waiting for the boss to spawn"},
        {"Cổng đã được xác nhận — đang tìm cổng/boss Cake Prince...", "Portal confirmed — locating the Cake Prince portal/boss..."},
        {"Đang kiểm tra cổng Cake Prince", "Checking the Cake Prince portal"},
        {"Cake Prince còn lại: ", "Cake Prince progress remaining: "},
        {"Tự động farm mục tiêu đã chọn", "Automatically farm the selected target"},
        {"Tự động nhận nhiệm vụ chuẩn theo cấp độ", "Automatically accept level-appropriate quests"},
        {"Gom quái xung quanh", "Gather nearby mobs"},
        {"Đang bay tới:", "Flying to:"},
        {"Đang tìm quái", "Searching for mobs"},
        {"Đang farm:", "Farming:"},
        {"Đã gửi", "Sent"},
        {"Đã nhận quest", "Quest accepted"},
        {"Nhận quest thất bại", "Quest acceptance failed"},
        {"Đã hạ", "Defeated"},
        {"Đang nói chuyện", "Talking"},
        {"đang chờ", "waiting"},
        {"Mục tiêu:", "Target:"},
        {"Trạng thái:", "Status:"},
        {"Hiện tại:", "Current:"},
        {"Đã tới", "Reached"},
        {"Đang đánh", "Fighting"},
        {"Đang bay", "Flying"},
        {"Đang tải", "Loading"},
        {"Đang kiểm tra", "Checking"},
        {"Không tìm thấy", "Not found"},
        {"Chưa có dữ liệu", "No data yet"},
        {"Chưa có nhân vật", "Character not available"},
        {"Đang chờ", "Waiting"},
        {"Đã tắt", "Disabled"},
        {"Đã bật", "Enabled"},
        {"Chỉ dùng được ở Sea 3", "Only available in Sea 3"},
        {"Cần level 2450+ để farm quái Tiki Outpost", "Level 2450+ required to farm Tiki Outpost mobs"},
        {"Cần Level 2600 trở lên", "Level 2600 or higher required"},
        {"Đã nhặt:", "Collected:"},
        {"Thấy trái:", "Fruit found:"},
        {"Không có trái nào trên đất", "No fruits on the ground"},
        {"Nhặt rương khi các tác vụ ưu tiên cao hơn đang rảnh", "Collect chests when higher-priority tasks are idle"},
        {"Auto Farm đã tắt", "Auto Farm disabled"},
        {"đang farm mục tiêu", "farming the target"},
        {"Hãy tắt Auto Dough King trước khi bay mua võ.", "Disable Auto Dough King before traveling to purchase a fighting style."},
    }

    local exactText = {vi = {}, en = {}}
    for _, pair in ipairs(exactPairs) do
        local en, vi = pair[1], pair[2]
        exactText.en[vi] = en
        exactText.vi[en] = vi
    end

    table.sort(phrasePairs, function(a, b)
        local al = math.max(#a[1], #a[2])
        local bl = math.max(#b[1], #b[2])
        return al > bl
    end)

    -- Start with the saved preference when available; default to English.
    local currentLanguage = "en"
    pcall(function()
        local env = getgenv and getgenv()
        if env and (env.MinhHubLanguage == "vi" or env.MinhHubLanguage == "en") then
            currentLanguage = env.MinhHubLanguage
        end
    end)

    local function replacePlain(text, needle, replacement)
        if needle == "" then return text end
        local first = string.find(text, needle, 1, true)
        if not first then return text end
        local output, cursor = {}, 1
        while first do
            output[#output + 1] = string.sub(text, cursor, first - 1)
            output[#output + 1] = replacement
            cursor = first + #needle
            first = string.find(text, needle, cursor, true)
        end
        output[#output + 1] = string.sub(text, cursor)
        return table.concat(output)
    end

    local translationCache = {vi = {}, en = {}}
    local function translateText(original, language)
        if type(original) ~= "string" or original == "" then return original end
        local cached = translationCache[language][original]
        if cached ~= nil then return cached end
        local exact = exactText[language][original]
        if exact ~= nil then
            translationCache[language][original] = exact
            return exact
        end
        local value = original
        for _, pair in ipairs(phrasePairs) do
            local from, to
            if language == "en" then from, to = pair[1], pair[2]
            else from, to = pair[2], pair[1] end
            value = replacePlain(value, from, to)
        end
        translationCache[language][original] = value
        return value
    end

    local rawText = setmetatable({}, {__mode = "k"})
    local renderedText = setmetatable({}, {__mode = "k"})
    local rawPlaceholder = setmetatable({}, {__mode = "k"})
    local renderedPlaceholder = setmetatable({}, {__mode = "k"})
    local watched = setmetatable({}, {__mode = "k"})

    local function renderText(obj)
        if not obj or not obj.Parent then return end
        local original = rawText[obj]
        if original == nil then return end
        local output = translateText(original, currentLanguage)
        renderedText[obj] = output
        if obj.Text ~= output then obj.Text = output end
    end

    local function renderPlaceholder(obj)
        if not obj or not obj.Parent then return end
        local original = rawPlaceholder[obj]
        if original == nil then return end
        local output = translateText(original, currentLanguage)
        renderedPlaceholder[obj] = output
        if obj.PlaceholderText ~= output then obj.PlaceholderText = output end
    end

    local function watchTextObject(obj)
        if watched[obj] then return end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            watched[obj] = true
            rawText[obj] = obj.Text
            obj:GetPropertyChangedSignal("Text"):Connect(function()
                local value = obj.Text
                if renderedText[obj] ~= nil and value == renderedText[obj] then return end
                rawText[obj] = value
                renderText(obj)
            end)
            renderText(obj)
        elseif obj:IsA("TextBox") then
            watched[obj] = true
            rawPlaceholder[obj] = obj.PlaceholderText
            obj:GetPropertyChangedSignal("PlaceholderText"):Connect(function()
                local value = obj.PlaceholderText
                if renderedPlaceholder[obj] ~= nil and value == renderedPlaceholder[obj] then return end
                rawPlaceholder[obj] = value
                renderPlaceholder(obj)
            end)
            renderPlaceholder(obj)
        end
    end

    for _, obj in ipairs(screenGui:GetDescendants()) do
        watchTextObject(obj)
    end
    screenGui.DescendantAdded:Connect(watchTextObject)

    -- Đồng bộ cả màn hình loading nếu nó vẫn đang hiển thị.
    local loadingGui
    pcall(function()
        loadingGui = screenGui.Parent and screenGui.Parent:FindFirstChild("MinhHubLoading")
    end)
    if loadingGui then
        for _, obj in ipairs(loadingGui:GetDescendants()) do
            watchTextObject(obj)
        end
        loadingGui.DescendantAdded:Connect(watchTextObject)
    end

    local languageCard = Instance.new("Frame")
    languageCard.Name = "LanguageSelectorCard"
    languageCard.Size = UDim2.new(1, 0, 0, 48)
    languageCard.BackgroundColor3 = BANANA_CARD
    languageCard.LayoutOrder = -100
    languageCard.Parent = settingsPage
    addCorner(languageCard, 8)
    addStroke(languageCard, BANANA_CARD_BORDER, 1.2)

    local languageTitle = Instance.new("TextLabel")
    languageTitle.Name = "LanguageTitle"
    languageTitle.Size = UDim2.new(1, -190, 1, 0)
    languageTitle.Position = UDim2.new(0, 10, 0, 0)
    languageTitle.BackgroundTransparency = 1
    languageTitle.Text = "🌐 Interface Language"
    languageTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    languageTitle.TextSize = 12
    languageTitle.Font = Enum.Font.GothamBold
    languageTitle.TextXAlignment = Enum.TextXAlignment.Left
    languageTitle.Parent = languageCard

    local function makeLanguageButton(name, caption, xOffset, width)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.new(0, width, 0, 28)
        button.Position = UDim2.new(1, xOffset, 0.5, -14)
        button.BackgroundColor3 = BANANA_SIDEBAR
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Text = caption
        button.TextColor3 = Color3.fromRGB(225, 227, 235)
        button.TextSize = 10
        button.Font = Enum.Font.GothamBold
        button.Parent = languageCard
        addCorner(button, 6)
        addStroke(button, BANANA_CARD_BORDER, 1)
        return button
    end

    local vietnameseButton = makeLanguageButton("VietnameseLanguageButton", "🇻🇳 Tiếng Việt", -180, 84)
    vietnameseButton.Visible = true
    local englishButton = makeLanguageButton("EnglishLanguageButton", "🇬🇧 English", -90, 84)

    local function refreshLanguageButtons()
        vietnameseButton.BackgroundColor3 = currentLanguage == "vi" and BANANA_YELLOW or BANANA_SIDEBAR
        englishButton.BackgroundColor3 = currentLanguage == "en" and BANANA_YELLOW or BANANA_SIDEBAR
        vietnameseButton.TextColor3 = currentLanguage == "vi" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 194, 205)
        englishButton.TextColor3 = currentLanguage == "en" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 194, 205)
    end

    local function setLanguage(language)
        if language ~= "en" and language ~= "vi" then return end
        currentLanguage = language
        pcall(function()
            local env = getgenv and getgenv()
            if env then env.MinhHubLanguage = language end
        end)
        -- Xoá cache để các chuỗi hiện tại được dựng lại theo ngôn ngữ mới.
        table.clear(translationCache.vi)
        table.clear(translationCache.en)
        for obj in pairs(rawText) do renderText(obj) end
        for obj in pairs(rawPlaceholder) do renderPlaceholder(obj) end
        refreshLanguageButtons()
    end

    vietnameseButton.MouseButton1Click:Connect(function() setLanguage("vi") end)
    englishButton.MouseButton1Click:Connect(function() setLanguage("en") end)
    setLanguage(currentLanguage)
end

do
    local searchWrap = Instance.new("Frame")
    searchWrap.Name = "SearchWrap"
    searchWrap.Size = UDim2.new(0.92, 0, 0, 30)
    searchWrap.LayoutOrder = -10
    searchWrap.BackgroundColor3 = BANANA_CARD
    searchWrap.Visible = false
    searchWrap.Parent = sidebar
    addCorner(searchWrap, 8)
    addStroke(searchWrap, BANANA_CARD_BORDER, 1)

    local searchIcon = Instance.new("TextLabel")
    searchIcon.Size = UDim2.new(0, 24, 1, 0)
    searchIcon.Position = UDim2.new(0, 4, 0, 0)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "🔍"
    searchIcon.TextSize = 12
    searchIcon.Font = Enum.Font.Gotham
    searchIcon.Parent = searchWrap

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -32, 1, 0)
    searchBox.Position = UDim2.new(0, 28, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.PlaceholderText = "Search section or Func..."
    searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 160)
    searchBox.Text = ""
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.TextSize = 11
    searchBox.Font = Enum.Font.GothamMedium
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = searchWrap

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = string.lower(searchBox.Text)
        for name, data in pairs(tabs) do
            data.Button.Visible = (q == "") or (string.find(string.lower(name), q, 1, true) ~= nil)
        end
    end)
end

local function createToggleFeature(parentPage, featureId, title, subTitle, layoutOrder, defaultState, callback)
    local hasSub = subTitle ~= nil and subTitle ~= ""
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, hasSub and 50 or 36)
    card.BackgroundColor3 = BANANA_CARD
    card.BackgroundTransparency = 0.35
    card.LayoutOrder = layoutOrder
    card.Parent = parentPage
    addCorner(card, 6)
    local cardStroke = addStroke(card, defaultState and BANANA_YELLOW or BANANA_CARD_BORDER, 1)
    cardStroke.Transparency = defaultState and 0.45 or 0.7

    local mainText = Instance.new("TextLabel")
    mainText.Size = UDim2.new(1, -60, 0, hasSub and 20 or 36)
    mainText.Position = UDim2.new(0, 12, 0, hasSub and 6 or 0)
    mainText.BackgroundTransparency = 1
    mainText.Text = title
    mainText.TextColor3 = defaultState and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 205, 212)
    mainText.TextSize = 12
    mainText.Font = Enum.Font.GothamMedium
    mainText.TextXAlignment = Enum.TextXAlignment.Left
    mainText.Parent = card

    if hasSub then
        local subText = Instance.new("TextLabel")
        subText.Size = UDim2.new(1, -60, 0, 16)
        subText.Position = UDim2.new(0, 12, 0, 28)
        subText.BackgroundTransparency = 1
        subText.Text = subTitle
        subText.TextColor3 = Color3.fromRGB(140, 140, 156)
        subText.TextSize = 10
        subText.Font = Enum.Font.Gotham
        subText.TextXAlignment = Enum.TextXAlignment.Left
        subText.Parent = card
    end

    local checkBox = Instance.new("Frame")
    checkBox.Size = UDim2.new(0, 20, 0, 20)
    checkBox.Position = UDim2.new(1, -32, 0.5, -10)
    checkBox.BackgroundColor3 = BANANA_SIDEBAR
    checkBox.Parent = card
    addCorner(checkBox, 5)
    addStroke(checkBox, BANANA_YELLOW, 2)

    local checkFill = Instance.new("Frame")
    checkFill.AnchorPoint = Vector2.new(0.5, 0.5)
    checkFill.Position = UDim2.new(0.5, 0, 0.5, 0)
    checkFill.Size = defaultState and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
    checkFill.BackgroundColor3 = BANANA_YELLOW
    checkFill.Parent = checkBox
    addCorner(checkFill, 3)

    local isToggled = defaultState
    local function setToggleState(state)
        isToggled = state
        TweenService:Create(checkFill, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = isToggled and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)}):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.16), {
            Color = isToggled and BANANA_YELLOW or BANANA_CARD_BORDER,
            Transparency = isToggled and 0.45 or 0.7,
        }):Play()
        TweenService:Create(mainText, TweenInfo.new(0.16), {
            TextColor3 = isToggled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 205, 212),
        }):Play()
    end

    local clickArea = Instance.new("TextButton")
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.Parent = card

    clickArea.MouseEnter:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(48, 48, 55)}):Play()
    end)
    clickArea.MouseLeave:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.12), {BackgroundColor3 = BANANA_CARD}):Play()
    end)

    clickArea.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        setToggleState(isToggled)
        callback(isToggled)
    end)

    if featureId then
        toggleUpdateFuncs[featureId] = setToggleState
    end
    -- đăng ký để nút ✕ (xóa menu) tắt được mọi chức năng đang bật
    Q.allToggles = Q.allToggles or {}
    Q.allToggles[#Q.allToggles + 1] = {
        isOn = function() return isToggled end,
        off = function() setToggleState(false) callback(false) end,
    }
end

-- TRẠNG THÁI CAKE PRINCE
local cakeStatusCard = Instance.new("Frame")
cakeStatusCard.Size = UDim2.new(1, 0, 0, 44)
cakeStatusCard.BackgroundColor3 = BANANA_CARD
cakeStatusCard.LayoutOrder = 0
cakeStatusCard.Parent = nil -- Ẩn thẻ trạng thái Cake Prince khỏi giao diện
addCorner(cakeStatusCard, 8)
addStroke(cakeStatusCard, Color3.fromRGB(255, 170, 0), 1.2)

local cakeStatusText = Instance.new("TextLabel")
cakeStatusText.Size = UDim2.new(1, -24, 1, 0)
cakeStatusText.Position = UDim2.new(0, 12, 0, 0)
cakeStatusText.BackgroundTransparency = 1
cakeStatusText.Text = "🎂 Cake Prince Status: Checking..."
cakeStatusText.TextColor3 = Color3.fromRGB(255, 215, 0)
cakeStatusText.TextSize = 12
cakeStatusText.Font = Enum.Font.GothamBold
cakeStatusText.TextXAlignment = Enum.TextXAlignment.Left
cakeStatusText.Parent = cakeStatusCard

local isCakePrinceReady = false
-- Chỉ true khi phản hồi xác nhận portal đã mở, boss đã xuất hiện, hoặc nhân vật đã vào Dimensional Shift.
-- Đủ 500 quái / nhận câu hỏi mở cổng KHÔNG đồng nghĩa portal đã mở.
Q.cakePortalOpen = Q.cakePortalOpen or false
-- Thời điểm gần nhất nhân vật đã thử đi vào cổng Cake Prince.
local cakePortalEntryAt = 0
-- Giữ trạng thái đã chuyển qua cổng để vòng farm không bay ngược về tọa độ cổng
-- trong lúc khu vực boss đang tải hoặc model boss chưa được stream vào client.
Q.cakePortalTransitioned = Q.cakePortalTransitioned or false
Q.cakePortalWaitPos = Q.cakePortalWaitPos or nil
Q.cakePortalTransitionedAt = Q.cakePortalTransitionedAt or 0
Q.cakeBossSeenInBossArea = Q.cakeBossSeenInBossArea or false
-- Được bật khi người chơi chết trong lúc farm Cake Prince. Giữ trạng thái này
-- để sau khi hồi sinh vẫn quay lại cổng, không bị chuyển nhầm về farm quái Cake Land.
Q.cakeReturnAfterDeath = Q.cakeReturnAfterDeath or false

-- Trạng thái riêng cho Bones để biết script đang tìm quái, di chuyển hay đang đánh.
Q.BonesFarm = Q.BonesFarm or { status = "Disabled", label = nil }
function Q.BonesFarm.setStatus(status)
    status = tostring(status or "Disabled")
    if Q.BonesFarm.status == status then return end
    Q.BonesFarm.status = status
    if Q.BonesFarm.label then
        pcall(function() Q.BonesFarm.label.Text = "💀 Farm Bones: " .. status end)
    end
end
;(function()
    local card = Instance.new("Frame")
    card.Name = "BonesFarmStatusCard"
    card.Size = UDim2.new(1, 0, 0, 38)
    card.BackgroundColor3 = BANANA_CARD
    card.LayoutOrder = 1
    card.Parent = nil -- Ẩn thẻ trạng thái Farm Bones khỏi giao diện
    addCorner(card, 8)
    addStroke(card, Color3.fromRGB(190, 195, 215), 1.1)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "💀 Farm Bones: Disabled"
    label.TextColor3 = Color3.fromRGB(220, 225, 240)
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = card
    Q.BonesFarm.label = label
end)()

-- Tìm boss Cake Prince / Dough King đang sống. Ưu tiên Enemies, đồng thời dự phòng
-- trường hợp model boss được đặt ở folder khác trong Workspace. Quét có cache để tránh lag.
function Q.FindLiveCakeBoss()
    local now = tick()
    local function isLiveBoss(mob)
        if typeof(mob) ~= "Instance" or not mob:IsA("Model") then return false end
        local name = string.lower(mob.Name)
        if not (string.find(name, "cake prince", 1, true) or string.find(name, "dough king", 1, true)) then
            return false
        end
        local hum = mob:FindFirstChildOfClass("Humanoid")
        local root = mob:FindFirstChild("HumanoidRootPart")
        return hum ~= nil and hum.Health > 0 and root ~= nil
    end

    local cached = Q._cakeBossCache
    if isLiveBoss(cached) then return cached end
    if now - (Q._cakeBossScanAt or 0) < 0.4 then return nil end
    Q._cakeBossScanAt = now
    -- Không xoá cache ngay: model boss có thể tạm thời mất HumanoidRootPart/Humanoid
    -- (stream / đổi phase). Chỉ xoá khi quét lại thật sự không thấy.
    local previous = cached
    Q._cakeBossCache = nil

    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, mob in ipairs(enemies:GetDescendants()) do
            if isLiveBoss(mob) then
                Q._cakeBossCache = mob
                return mob
            end
        end
    end

    -- Dự phòng: một số bản game/executor có thể stream model boss ngoài Enemies.
    -- Quét toàn Workspace tối đa khoảng một lần mỗi 1.5 giây khi Enemies không có boss.
    if now - (Q._cakeWorkspaceBossScanAt or 0) >= 1.5 then
        Q._cakeWorkspaceBossScanAt = now
        for _, mob in ipairs(workspace:GetDescendants()) do
            if isLiveBoss(mob) then
                Q._cakeBossCache = mob
                return mob
            end
        end
    end

    -- Boss vẫn còn trong workspace và còn máu nhưng vừa mất HumanoidRootPart (stream tạm thời):
    -- vẫn coi là đang sống, tránh script tưởng boss đã chết -> reset trạng thái.
    if typeof(previous) == "Instance" and previous.Parent then
        local pHum = previous:FindFirstChildOfClass("Humanoid")
        if pHum and pHum.Health > 0 and previous:FindFirstChild("HumanoidRootPart") then
            Q._cakeBossCache = previous
            return previous
        end
    end
    return nil
end

function Q.CakeHasLiveBoss()
    return Q.FindLiveCakeBoss() ~= nil
end

-- Chui vào cổng Cake Prince: mỗi 2.5s dịch chuyển nhẹ quanh tâm cổng (đổi vị trí mỗi lần để chắc chắn trúng vùng kích hoạt)
-- và firetouchinterest các part giống cổng/portal gần đó. Dừng khi boss xuất hiện (vòng farm chính sẽ đánh boss).
Q.cakeTry, Q.cakeLastTouch, Q.cakeParts, Q.cakePartsAt = 0, 0, {}, -100
function Q.cakeEnterGate(hrp)
    if not hrp or not hrp.Parent then return end
    -- Chỉ thử kích hoạt khi đã tới đúng khu vực cổng; tránh ghi nhận "đã vào cổng"
    -- trong lúc nhân vật còn đang bay từ đảo bánh tới.
    if (hrp.Position - CAKE_PRINCE_GATE_POS).Magnitude > 24 then
        Q.cakeGateSince = nil
        return
    end
    if Q.CakeHasLiveBoss() then Q.cakeGateSince = nil end
    if not Q.cakeGateSince then Q.cakeGateSince = tick() end
    -- WATCHDOG: đứng ở cổng quá 40 giây mà boss không xuất hiện và chưa qua cổng
    -- (cổng chưa mở / boss đã chết lúc mình chết / cổng đóng) -> reset trạng thái và gửi lệnh mở cổng lại,
    -- thay vì lặp chui cổng vô hạn.
    if tick() - Q.cakeGateSince > 40 and not Q.CakeHasLiveBoss() and not Q.cakePortalTransitioned then
        Q.cakeGateSince = nil
        Q.cakeReturnAfterDeath = false
        Q.cakeBossSeen = false
        Q.cakePortalOpen = false
        Q.cakeLatchUntil = 0
        Q.cakeNeedSummon = true
        Q.cakeSummonAt = 0
        isCakePrinceReady = false
        cakePortalEntryAt = 0
        Q.cakeTry = 0
        Q.cakePortalTransitioned = false
        Q._cakeBossCache = nil
        cakeStatusText.Text = "♻️ Cổng không phản hồi sau 40s — đang kiểm tra / mở cổng lại..."
        print("[CakePrince] Kẹt ở cổng 40s không có boss; reset và mở cổng lại")
        return
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    if tick() - Q.cakeLastTouch < 2.5 then return end
    Q.cakeLastTouch = tick()
    Q.cakeTry = Q.cakeTry + 1
    if cakePortalEntryAt == 0 then
        cakePortalEntryAt = tick()
        Q.cakePortalTransitioned = false
        Q.cakePortalWaitPos = nil
        Q.cakePortalTransitionedAt = 0
        Q.cakeBossSeenInBossArea = false
    end

    local offsets = {Vector3.new(0, 1, 0), Vector3.new(0, 1, -8), Vector3.new(0, 1, 8), Vector3.new(8, 1, 0), Vector3.new(-8, 1, 0)}
    local off = offsets[((Q.cakeTry - 1) % #offsets) + 1]
    hrp.CFrame = CFrame.new(CAKE_PRINCE_GATE_POS + off)

    if typeof(firetouchinterest) == "function" then
        if tick() - Q.cakePartsAt > 10 then
            Q.cakePartsAt = tick()
            Q.cakeParts = {}
            local map = workspace:FindFirstChild("Map")
            if map then
                for _, d in ipairs(map:GetDescendants()) do
                    if d:IsA("BasePart") and (d.Position - CAKE_PRINCE_GATE_POS).Magnitude <= 60 then
                        local n = string.lower(d.Name)
                        if string.find(n, "portal", 1, true) or string.find(n, "gate", 1, true) or string.find(n, "door", 1, true)
                            or string.find(n, "teleport", 1, true) or string.find(n, "enter", 1, true) or string.find(n, "whirlpool", 1, true) then
                            Q.cakeParts[#Q.cakeParts + 1] = d
                        end
                    end
                end
            end
        end
        for _, p in ipairs(Q.cakeParts) do
            if p.Parent then pcall(function() firetouchinterest(hrp, p, 0); firetouchinterest(hrp, p, 1) end) end
        end
    end
    cakeStatusText.Text = "🚪 Đang chui vào cổng Cake Prince (lần " .. Q.cakeTry .. ") — chờ boss xuất hiện..."
end

-- Đọc nhiều dạng phản hồi của CakePrinceSpawner, kể cả số 0 và tiến độ dạng a/b.
function Q.UpdateCakeSpawnerStatus(result)
    if result == nil then return end

    local raw = tostring(result)
    local lower = string.lower(raw)
    local current, total = string.match(raw, "(%d+)%s*/%s*(%d+)")
    local remaining

    if current and total then
        current, total = tonumber(current), tonumber(total)
        if current and total and total > 0 then
            remaining = math.max(0, total - current)
        end
    else
        remaining = tonumber(result) or tonumber(string.match(raw, "(%d+)"))
    end

    -- Những phản hồi này xác nhận cổng/dimension đã mở thật sự.
    -- Thêm "portal is already open" vì chuỗi này không khớp với "portal is open".
    local explicitlyOpen =
        string.find(lower, "portal is already open", 1, true) ~= nil
        or string.find(lower, "already open", 1, true) ~= nil
        or string.find(lower, "portal is open", 1, true) ~= nil
        or string.find(lower, "dimension is open", 1, true) ~= nil
        or string.find(lower, "dimension has spawned", 1, true) ~= nil
        or string.find(lower, "has appeared", 1, true) ~= nil
        or string.find(lower, "spawned", 1, true) ~= nil
        or string.find(lower, "ready to fight", 1, true) ~= nil
        or lower == "open"

    local explicitlyClosed =
        string.find(lower, "not open", 1, true) ~= nil
        or string.find(lower, "not spawned", 1, true) ~= nil
        or string.find(lower, "not ready", 1, true) ~= nil

    -- Đây chỉ là lời mời xác nhận "Yes", không phải bằng chứng cổng đã mở.
    local askPortal =
        string.find(lower, "do you want to open the portal", 1, true) ~= nil
        or string.find(lower, "open the portal now", 1, true) ~= nil
        or string.find(lower, "open portal", 1, true) ~= nil

    local liveBoss = Q.CakeHasLiveBoss()
    if liveBoss or (explicitlyOpen and not explicitlyClosed) then
        Q.cakePortalOpen = true
        Q.cakeNeedSummon = false
        Q.cakeLatchUntil = tick() + 150
        isCakePrinceReady = true
        EH.cakeLeft = 0
        cakeStatusText.Text = liveBoss
            and "👑 Cake Prince / Dough King đã xuất hiện — bay vào cổng để farm!"
            or "✅ Đã xác nhận cổng Cake Prince mở — đang bay đến cổng..."
        return
    end

    -- Chỉ gửi yêu cầu mở cổng khi chưa có một lượt portal/boss đã được xác nhận.
    local alreadyInRun = Q.cakePortalOpen
        or Q.cakePortalTransitioned
        or Q.cakeReturnAfterDeath
        or (Q.cakeBossSeen == true)
    if not alreadyInRun and (askPortal or (remaining ~= nil and remaining <= 0)) then
        Q.cakeNeedSummon = true
    end

    -- Không dùng bộ đếm 0 hoặc câu hỏi mở cổng để tự đánh dấu là cổng đã mở.

    if explicitlyClosed and not Q.cakePortalTransitioned and not Q.cakeReturnAfterDeath and not Q.cakeBossSeen then
        Q.cakePortalOpen = false
        alreadyInRun = false
    end

    isCakePrinceReady = alreadyInRun
    if isCakePrinceReady then
        EH.cakeLeft = 0
        cakeStatusText.Text = "✅ Cổng đã được xác nhận — đang tìm cổng/boss Cake Prince..."
    elseif remaining ~= nil then
        EH.cakeLeft = math.max(0, remaining)
        if EH.cakeLeft <= 0 or askPortal then
            cakeStatusText.Text = "🎂 Đủ điều kiện 500 quái — đang mở/xác minh cổng; chưa xác nhận thì tiếp tục farm Cake Land."
        else
            cakeStatusText.Text = "🎂 Cake Prince còn lại: " .. tostring(EH.cakeLeft) .. " / 500 con"
        end
    else
        EH.cakeLeft = nil
        if askPortal then
            cakeStatusText.Text = "🎂 Đã đủ điều kiện nhưng cổng chưa xác nhận mở — đang thử mở cổng..."
        else
            cakeStatusText.Text = "🎂 Đang kiểm tra cổng Cake Prince: " .. raw
        end
    end
end

_G.MHSpawn(function()
    while true do
        task.wait(4) -- chỉ kiểm tra định kỳ; không gọi remote liên tục theo từng frame
        pcall(function()
            if Q.CakeHasLiveBoss() then
                Q.UpdateCakeSpawnerStatus("spawned")
                return
            end
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local commF = remotes and remotes:FindFirstChild("CommF_")
            if commF then
                local result = commF:InvokeServer("CakePrinceSpawner")
                Q.UpdateCakeSpawnerStatus(result)

                -- Chỉ chọn "Yes" khi Drip_mama cho mở cổng; không giả định lệnh gửi đi là mở thành công.
                -- Nếu server chưa xác nhận mở cổng, isCakePrinceReady vẫn false và vòng chính tiếp tục farm Cake Land.
                if Q.cakeNeedSummon and autoFarmEnabled and selectedFarmTarget == "Cake Prince" and World3
                    and not (Q.DK and Q.DK.on) and not Q.CakeHasLiveBoss()
                    and tick() >= (Q.cakeSummonBlockUntil or 0)
                    and not Q.cakeBossSeen and not Q.cakePortalTransitioned
                    and tick() - (Q.cakeSummonAt or 0) >= 8 then
                    Q.cakeSummonAt = tick()
                    Q.cakeSummonN = (Q.cakeSummonN or 0) + 1
                    Q.cakeNeedSummon = false
                    local okS, r2 = pcall(function()
                        return commF:InvokeServer("CakePrinceSpawner", true)
                    end)
                    if okS then
                        Q.UpdateCakeSpawnerStatus(r2)
                        if not isCakePrinceReady then
                            cakeStatusText.Text = "🎂 Đã gửi xác nhận mở cổng; chưa thấy trạng thái cổng mở nên tiếp tục farm Cake Land và kiểm tra lại..."
                            -- Cho phép thử lại nếu server vẫn trả lời rằng cần xác nhận mở cổng.
                            if r2 == nil then Q.cakeNeedSummon = true end
                        end
                    else
                        Q.cakeNeedSummon = true
                        cakeStatusText.Text = "⚠️ Gửi lệnh mở cổng thất bại; tiếp tục farm Cake Land và sẽ thử lại."
                    end
                    print("[CakePrince] Gửi lệnh mở cổng lần", Q.cakeSummonN, okS, r2)
                end
            end
        end)
    end
end)

-- TAB AUTO FARM CONTENT
local farmDropdownCard = Instance.new("Frame")
farmDropdownCard.Size = UDim2.new(1, 0, 0, 44)
farmDropdownCard.BackgroundColor3 = BANANA_CARD
farmDropdownCard.LayoutOrder = 11
farmDropdownCard.ClipsDescendants = true
farmDropdownCard.Parent = farmPage
addCorner(farmDropdownCard, 8)
addStroke(farmDropdownCard, BANANA_CARD_BORDER, 1.2)

local farmDropdownBtn = Instance.new("TextButton")
farmDropdownBtn.Size = UDim2.new(1, 0, 0, 44)
farmDropdownBtn.BackgroundTransparency = 1
farmDropdownBtn.Text = ""
farmDropdownBtn.Parent = farmDropdownCard

local farmDropdownLabel = Instance.new("TextLabel")
farmDropdownLabel.Size = UDim2.new(1, -45, 1, 0)
farmDropdownLabel.Position = UDim2.new(0, 12, 0, 0)
farmDropdownLabel.BackgroundTransparency = 1
farmDropdownLabel.Text = "Target: " .. selectedFarmTarget
farmDropdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
farmDropdownLabel.TextSize = 12
farmDropdownLabel.Font = Enum.Font.GothamBold
farmDropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
farmDropdownLabel.Parent = farmDropdownBtn

local farmArrow = Instance.new("TextLabel")
farmArrow.Size = UDim2.new(0, 35, 1, 0)
farmArrow.Position = UDim2.new(1, -35, 0, 0)
farmArrow.BackgroundTransparency = 1
farmArrow.Text = "▼"
farmArrow.TextColor3 = BANANA_YELLOW
farmArrow.TextSize = 12
farmArrow.Font = Enum.Font.GothamBold
farmArrow.Parent = farmDropdownBtn

local farmOptionsList = Instance.new("Frame")
farmOptionsList.Size = UDim2.new(1, -20, 0, 145)
farmOptionsList.Position = UDim2.new(0, 10, 0, 44)
farmOptionsList.BackgroundTransparency = 1
farmOptionsList.Parent = farmDropdownCard

local farmListLayout = Instance.new("UIListLayout")
farmListLayout.Parent = farmOptionsList
farmListLayout.SortOrder = Enum.SortOrder.LayoutOrder
farmListLayout.Padding = UDim.new(0, 6)

local isFarmDropdownOpen = false
farmDropdownBtn.MouseButton1Click:Connect(function()
    isFarmDropdownOpen = not isFarmDropdownOpen
    farmArrow.Text = isFarmDropdownOpen and "▲" or "▼"
    farmDropdownCard.Size = isFarmDropdownOpen and UDim2.new(1, 0, 0, 195) or UDim2.new(1, 0, 0, 44)
end)

local farmOptionBtns = {}
for index, targetName in ipairs({"Auto Level", "Cake Prince", "Bones", "Nearby Mobs"}) do
    local optBtn = Instance.new("TextButton")
    optBtn.Size = UDim2.new(1, 0, 0, 30)
    optBtn.Text = "   " .. targetName
    optBtn.TextXAlignment = Enum.TextXAlignment.Left
    optBtn.Font = Enum.Font.GothamBold
    optBtn.TextSize = 12
    optBtn.LayoutOrder = index
    optBtn.Parent = farmOptionsList
    addCorner(optBtn, 6)

    if targetName == selectedFarmTarget then
        optBtn.BackgroundColor3 = BANANA_YELLOW
        optBtn.TextColor3 = BANANA_TEXT_ON
    else
        optBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        optBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
    end

    optBtn.MouseButton1Click:Connect(function()
        selectedFarmTarget = targetName
        farmDropdownLabel.Text = "Target: " .. selectedFarmTarget
        isFarmDropdownOpen = false
        farmArrow.Text = "▼"
        farmDropdownCard.Size = UDim2.new(1, 0, 0, 44)

        for name, btn in pairs(farmOptionBtns) do
            if name == selectedFarmTarget then
                btn.BackgroundColor3 = BANANA_YELLOW
                btn.TextColor3 = BANANA_TEXT_ON
            else
                btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                btn.TextColor3 = Color3.fromRGB(150, 150, 160)
            end
        end
    end)
    farmOptionBtns[targetName] = optBtn
end

-- DISTANCE FARM NEARBY MOBS SLIDER (ngay dưới ô chọn chế độ farm)
;(function()
    local MIN_R, MAX_R = 50, 1000
    local startR = math.clamp(tonumber(_G.NearbyMobRadius) or 400, MIN_R, MAX_R)
    _G.NearbyMobRadius = startR

    local card = Instance.new("Frame")
    card.Name = "NearbyMobDistanceCard"
    card.Size = UDim2.new(1, 0, 0, 56)
    card.BackgroundColor3 = BANANA_CARD
    card.LayoutOrder = 12
    card.Parent = farmPage
    addCorner(card, 8)
    addStroke(card, BANANA_CARD_BORDER, 1.2)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.65, 0, 0, 28)
    title.Position = UDim2.new(0, 12, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "Distance Farm Nearby Mobs"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 60, 0, 24)
    box.Position = UDim2.new(1, -70, 0, 6)
    box.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.TextSize = 12
    box.Font = Enum.Font.GothamBold
    box.Text = tostring(startR)
    box.ClearTextOnFocus = false
    box.Parent = card
    addCorner(box, 6)

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -24, 0, 8)
    track.Position = UDim2.new(0, 12, 1, -14)
    track.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = card
    addCorner(track, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((startR - MIN_R) / (MAX_R - MIN_R), 0, 1, 0)
    fill.BackgroundColor3 = BANANA_YELLOW
    fill.BorderSizePixel = 0
    fill.Parent = track
    addCorner(fill, 4)

    local function setRadius(v)
        v = math.clamp(math.floor(v), MIN_R, MAX_R)
        _G.NearbyMobRadius = v
        box.Text = tostring(v)
        fill.Size = UDim2.new((v - MIN_R) / (MAX_R - MIN_R), 0, 1, 0)
    end

    local dragging = false
    local function fromX(x)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local rel = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        setRadius(MIN_R + rel * (MAX_R - MIN_R))
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then setRadius(n) else box.Text = tostring(_G.NearbyMobRadius) end
    end)
end)()

createToggleFeature(farmPage, "AutoFarmTargetToggle", "Auto Farm", "Automatically farm the selected target", 13, autoFarmEnabled, function(state)
    autoFarmEnabled = state
    if not state and selectedFarmTarget == "Bones" and Q.BonesFarm then
        Q.BonesFarm.setStatus("Disabled")
    end
    if state then
        if toggleUpdateFuncs["AutoFarmMaterialToggle"] then toggleUpdateFuncs["AutoFarmMaterialToggle"](false) end
        if toggleUpdateFuncs["AutoFarmBossToggle"] then toggleUpdateFuncs["AutoFarmBossToggle"](false) end
        if toggleUpdateFuncs["AutoRaidToggle"] then toggleUpdateFuncs["AutoRaidToggle"](false) end
        -- FIX: toggleUpdateFuncs chỉ đổi hình ô tick, phải tự tắt biến thật để không chạy chồng chéo.
        autoFarmMaterialEnabled = false
        autoRaidEnabled = false
        _G.Dungeon = false
    end
end)

createToggleFeature(farmPage, "AutoQuestToggle", "Auto Quest", "Automatically accept level-appropriate quests (including Haunted Castle)", 14, autoQuestEnabled, function(state)
    autoQuestEnabled = state
end)

-- UI & COMPONENT CHỨC NĂNG AUTO FARM MATERIAL
local materialDropdownCard = Instance.new("Frame")
materialDropdownCard.Size = UDim2.new(1, 0, 0, 44)
materialDropdownCard.BackgroundColor3 = BANANA_CARD
materialDropdownCard.LayoutOrder = 21
materialDropdownCard.ClipsDescendants = true
materialDropdownCard.Parent = farmPage
addCorner(materialDropdownCard, 8)
addStroke(materialDropdownCard, BANANA_CARD_BORDER, 1.2)

local materialDropdownBtn = Instance.new("TextButton")
materialDropdownBtn.Size = UDim2.new(1, 0, 0, 44)
materialDropdownBtn.BackgroundTransparency = 1
materialDropdownBtn.Text = ""
materialDropdownBtn.Parent = materialDropdownCard

local materialDropdownLabel = Instance.new("TextLabel")
materialDropdownLabel.Size = UDim2.new(1, -45, 1, 0)
materialDropdownLabel.Position = UDim2.new(0, 12, 0, 0)
materialDropdownLabel.BackgroundTransparency = 1
materialDropdownLabel.Text = "📦 Material (Sea " .. tostring(currentSeaIndex) .. "): " .. selectedMaterialTarget
materialDropdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
materialDropdownLabel.TextSize = 12
materialDropdownLabel.Font = Enum.Font.GothamBold
materialDropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
materialDropdownLabel.Parent = materialDropdownBtn

local materialArrow = Instance.new("TextLabel")
materialArrow.Size = UDim2.new(0, 35, 1, 0)
materialArrow.Position = UDim2.new(1, -35, 0, 0)
materialArrow.BackgroundTransparency = 1
materialArrow.Text = "▼"
materialArrow.TextColor3 = BANANA_YELLOW
materialArrow.TextSize = 12
materialArrow.Font = Enum.Font.GothamBold
materialArrow.Parent = materialDropdownBtn

local materialOptionsList = Instance.new("ScrollingFrame")
materialOptionsList.Size = UDim2.new(1, -20, 0, 140)
materialOptionsList.Position = UDim2.new(0, 10, 0, 44)
materialOptionsList.BackgroundTransparency = 1
materialOptionsList.BorderSizePixel = 0
materialOptionsList.ScrollBarThickness = 3
materialOptionsList.ScrollBarImageColor3 = BANANA_YELLOW
materialOptionsList.Parent = materialDropdownCard

local materialListLayout = Instance.new("UIListLayout")
materialListLayout.Parent = materialOptionsList
materialListLayout.SortOrder = Enum.SortOrder.LayoutOrder
materialListLayout.Padding = UDim.new(0, 6)

local isMaterialDropdownOpen = false
materialDropdownBtn.MouseButton1Click:Connect(function()
    isMaterialDropdownOpen = not isMaterialDropdownOpen
    materialArrow.Text = isMaterialDropdownOpen and "▲" or "▼"
    materialDropdownCard.Size = isMaterialDropdownOpen and UDim2.new(1, 0, 0, 195) or UDim2.new(1, 0, 0, 44)
end)

local materialOptionBtns = {}
local materialListNames = {
    "Scrap Metal & Leather", 
    "Angel Wing", 
    "Fish Tail", 
    "Magma Ore", 
    "Vampire Fang", 
    "Ectoplasm",
    "Radioactive Material", 
    "Mystic Droplet", 
    "Dragon Scale", 
    "Conjured Cocoa", 
    "Mini Tusk", 
    "Demonic Soul"
}

-- Chỉ hiện nguyên liệu có thể farm ở Sea đang đứng (Sea 1 / 2 / 3)
do
    local filtered = {}
    for _, name in ipairs(materialListNames) do
        local d = materialData[name]
        if d and d[currentSeaIndex] then filtered[#filtered + 1] = name end
    end
    materialListNames = filtered
    local valid = false
    for _, name in ipairs(materialListNames) do
        if name == selectedMaterialTarget then valid = true break end
    end
    if not valid then selectedMaterialTarget = materialListNames[1] or "" end
    materialDropdownLabel.Text = "📦 Material (Sea " .. tostring(currentSeaIndex) .. "): " .. selectedMaterialTarget
end

for index, matName in ipairs(materialListNames) do
    local optBtn = Instance.new("TextButton")
    optBtn.Size = UDim2.new(1, -6, 0, 30)
    optBtn.Text = "   " .. matName
    optBtn.TextXAlignment = Enum.TextXAlignment.Left
    optBtn.Font = Enum.Font.GothamBold
    optBtn.TextSize = 12
    optBtn.LayoutOrder = index
    optBtn.Parent = materialOptionsList
    addCorner(optBtn, 6)

    if matName == selectedMaterialTarget then
        optBtn.BackgroundColor3 = BANANA_YELLOW
        optBtn.TextColor3 = BANANA_TEXT_ON
    else
        optBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        optBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
    end

    optBtn.MouseButton1Click:Connect(function()
        selectedMaterialTarget = matName
        currentMatPointIndex = 1
        materialDropdownLabel.Text = "📦 Material (Sea " .. tostring(currentSeaIndex) .. "): " .. selectedMaterialTarget
        isMaterialDropdownOpen = false
        materialArrow.Text = "▼"
        materialDropdownCard.Size = UDim2.new(1, 0, 0, 44)

        for name, btn in pairs(materialOptionBtns) do
            if name == selectedMaterialTarget then
                btn.BackgroundColor3 = BANANA_YELLOW
                btn.TextColor3 = BANANA_TEXT_ON
            else
                btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                btn.TextColor3 = Color3.fromRGB(150, 150, 160)
            end
        end
    end)
    materialOptionBtns[matName] = optBtn
end
materialOptionsList.CanvasSize = UDim2.new(0, 0, 0, #materialListNames * 36)

createToggleFeature(farmPage, "AutoFarmMaterialToggle", "Auto Farm Material", "Fly to and defeat mobs that drop the selected material", 22, autoFarmMaterialEnabled, function(state)
    autoFarmMaterialEnabled = state
    if state then
        currentMatPointIndex = 1
        if toggleUpdateFuncs["AutoFarmTargetToggle"] then toggleUpdateFuncs["AutoFarmTargetToggle"](false) end
        if toggleUpdateFuncs["AutoFarmBossToggle"] then toggleUpdateFuncs["AutoFarmBossToggle"](false) end
        if toggleUpdateFuncs["AutoRaidToggle"] then toggleUpdateFuncs["AutoRaidToggle"](false) end
        autoFarmEnabled = false
        autoRaidEnabled = false
        _G.Dungeon = false
    end
end)

-- TAB BOSS CONTENT
local bossDropdownCard = Instance.new("Frame")
bossDropdownCard.Size = UDim2.new(1, 0, 0, 44)
bossDropdownCard.BackgroundColor3 = BANANA_CARD
bossDropdownCard.LayoutOrder = 1
bossDropdownCard.ClipsDescendants = true
bossDropdownCard.Parent = bossPage
addCorner(bossDropdownCard, 8)
addStroke(bossDropdownCard, BANANA_CARD_BORDER, 1.2)

local bossDropdownBtn = Instance.new("TextButton")
bossDropdownBtn.Size = UDim2.new(1, 0, 0, 44)
bossDropdownBtn.BackgroundTransparency = 1
bossDropdownBtn.Text = ""
bossDropdownBtn.Parent = bossDropdownCard

local bossDropdownLabel = Instance.new("TextLabel")
bossDropdownLabel.Size = UDim2.new(1, -45, 1, 0)
bossDropdownLabel.Position = UDim2.new(0, 12, 0, 0)
bossDropdownLabel.BackgroundTransparency = 1
bossDropdownLabel.Text = "👑 Boss: " .. selectedBossTarget
bossDropdownLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
bossDropdownLabel.TextSize = 12
bossDropdownLabel.Font = Enum.Font.GothamBold
bossDropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
bossDropdownLabel.Parent = bossDropdownBtn

local bossArrow = Instance.new("TextLabel")
bossArrow.Size = UDim2.new(0, 35, 1, 0)
bossArrow.Position = UDim2.new(1, -35, 0, 0)
bossArrow.BackgroundTransparency = 1
bossArrow.Text = "▼"
bossArrow.TextColor3 = BANANA_YELLOW
bossArrow.TextSize = 12
bossArrow.Font = Enum.Font.GothamBold
bossArrow.Parent = bossDropdownBtn

local bossListScroll = Instance.new("ScrollingFrame")
bossListScroll.Size = UDim2.new(1, -20, 0, 180)
bossListScroll.Position = UDim2.new(0, 10, 0, 44)
bossListScroll.BackgroundTransparency = 1
bossListScroll.BorderSizePixel = 0
bossListScroll.ScrollBarThickness = 3
bossListScroll.ScrollBarImageColor3 = BANANA_YELLOW
bossListScroll.Parent = bossDropdownCard

local bossListLayout = Instance.new("UIListLayout")
bossListLayout.Parent = bossListScroll
bossListLayout.SortOrder = Enum.SortOrder.LayoutOrder
bossListLayout.Padding = UDim.new(0, 5)

local isBossDropdownOpen = false
bossDropdownBtn.MouseButton1Click:Connect(function()
    isBossDropdownOpen = not isBossDropdownOpen
    bossArrow.Text = isBossDropdownOpen and "▲" or "▼"
    bossDropdownCard.Size = isBossDropdownOpen and UDim2.new(1, 0, 0, 230) or UDim2.new(1, 0, 0, 44)
end)

local bossBtns = {}
local function renderBossList()
    for _, child in pairs(bossListScroll:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end
    bossBtns = {}
    local currentLayoutOrder = 1
    do
        local seaName, bosses = "Sea " .. currentSeaIndex, (seaBosses[currentSeaIndex] or {})
        local seaLabel = Instance.new("TextLabel")
        seaLabel.Size = UDim2.new(1, 0, 0, 22)
        seaLabel.BackgroundTransparency = 1
        seaLabel.Text = "  📌 " .. seaName
        seaLabel.TextColor3 = BANANA_YELLOW
        seaLabel.Font = Enum.Font.GothamBold
        seaLabel.TextSize = 11
        seaLabel.TextXAlignment = Enum.TextXAlignment.Left
        seaLabel.LayoutOrder = currentLayoutOrder
        seaLabel.Parent = bossListScroll
        currentLayoutOrder = currentLayoutOrder + 1

        for _, bName in ipairs(bosses) do
            local bBtn = Instance.new("TextButton")
            bBtn.Size = UDim2.new(1, -6, 0, 28)
            bBtn.Text = "     " .. bName
            bBtn.TextXAlignment = Enum.TextXAlignment.Left
            bBtn.Font = Enum.Font.Gotham
            bBtn.TextSize = 11
            bBtn.LayoutOrder = currentLayoutOrder
            bBtn.Parent = bossListScroll
            currentLayoutOrder = currentLayoutOrder + 1
            addCorner(bBtn, 6)

            if bName == selectedBossTarget then
                bBtn.BackgroundColor3 = BANANA_YELLOW
                bBtn.TextColor3 = BANANA_TEXT_ON
            else
                bBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                bBtn.TextColor3 = Color3.fromRGB(160, 160, 170)
            end

            bBtn.MouseButton1Click:Connect(function()
                selectedBossTarget = bName
                bossDropdownLabel.Text = "👑 Boss: " .. selectedBossTarget
                isBossDropdownOpen = false
                bossArrow.Text = "▼"
                bossDropdownCard.Size = UDim2.new(1, 0, 0, 44)

                for name, btn in pairs(bossBtns) do
                    if name == selectedBossTarget then
                        btn.BackgroundColor3 = BANANA_YELLOW
                        btn.TextColor3 = BANANA_TEXT_ON
                    else
                        btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                        btn.TextColor3 = Color3.fromRGB(160, 160, 170)
                    end
                end
            end)
            bossBtns[bName] = bBtn
        end
    end
    bossListScroll.CanvasSize = UDim2.new(0, 0, 0, currentLayoutOrder * 32)
end
renderBossList()

createToggleFeature(bossPage, "AutoFarmBossToggle", "Auto Farm Boss", "Automatically travel to and defeat the selected Boss", 2, false, function(state)
    if state then
        selectedFarmTarget = "Farm Boss"
        if toggleUpdateFuncs["AutoFarmTargetToggle"] then toggleUpdateFuncs["AutoFarmTargetToggle"](false) end
        if toggleUpdateFuncs["AutoFarmMaterialToggle"] then toggleUpdateFuncs["AutoFarmMaterialToggle"](false) end
        if toggleUpdateFuncs["AutoRaidToggle"] then toggleUpdateFuncs["AutoRaidToggle"](false) end
        autoFarmMaterialEnabled = false
        autoRaidEnabled = false
        _G.Dungeon = false
        autoFarmEnabled = true
    else
        autoFarmEnabled = false
    end
end)

-- Đã bỏ các thẻ trạng thái trong TAB Boss theo yêu cầu.

createToggleFeature(bossPage, "AutoEliteHunterToggle", "Auto Elite Hunter", "Automatically accept Elite quests and defeat Diablo / Urban / Deandre (Sea 3)", 5, false, function(state)
    if state then
        if not World3 then
            EH.status = "Elite Hunter chỉ có ở Sea 3"
        end
        if toggleUpdateFuncs["AutoFarmTargetToggle"] then toggleUpdateFuncs["AutoFarmTargetToggle"](false) end
        if toggleUpdateFuncs["AutoFarmMaterialToggle"] then toggleUpdateFuncs["AutoFarmMaterialToggle"](false) end
        if toggleUpdateFuncs["AutoFarmBossToggle"] then toggleUpdateFuncs["AutoFarmBossToggle"](false) end
        if toggleUpdateFuncs["AutoRaidToggle"] then toggleUpdateFuncs["AutoRaidToggle"](false) end
        autoFarmEnabled = false
        autoFarmMaterialEnabled = false
        autoRaidEnabled = false
        _G.Dungeon = false
        _G.EliteHunter = true
    else
        _G.EliteHunter = false
        _G.EliteBusy = false
        EH.status = "Disabled"
        targetEnemy = nil
        stopAllFlying()
    end
end)


-- TAB RAID CONTENT
local raidFrame = Instance.new("Frame")
raidFrame.Size = UDim2.new(1, 0, 0, 204)
raidFrame.BackgroundColor3 = BANANA_CARD
raidFrame.LayoutOrder = 1
raidFrame.Parent = raidPage
addCorner(raidFrame, 8)
addStroke(raidFrame, BANANA_CARD_BORDER, 1.2)

local raidTitle = Instance.new("TextLabel")
raidTitle.Size = UDim2.new(1, -24, 0, 32)
raidTitle.Position = UDim2.new(0, 12, 0, 4)
raidTitle.BackgroundTransparency = 1
raidTitle.Text = "🔥 Select Raid Chip: " .. selectedRaidChip
raidTitle.TextColor3 = Color3.fromRGB(255, 120, 0)
raidTitle.TextSize = 12
raidTitle.Font = Enum.Font.GothamBold
raidTitle.TextXAlignment = Enum.TextXAlignment.Left
raidTitle.Parent = raidFrame

local raidListScroll = Instance.new("ScrollingFrame")
raidListScroll.Size = UDim2.new(1, -20, 0, 134)
raidListScroll.Position = UDim2.new(0, 10, 0, 36)
raidListScroll.BackgroundTransparency = 1
raidListScroll.BorderSizePixel = 0
raidListScroll.ScrollBarThickness = 3
raidListScroll.ScrollBarImageColor3 = BANANA_YELLOW
raidListScroll.Parent = raidFrame

local raidListLayout = Instance.new("UIListLayout")
raidListLayout.Parent = raidListScroll
raidListLayout.SortOrder = Enum.SortOrder.LayoutOrder
raidListLayout.Padding = UDim.new(0, 5)

local chipBtns = {}
for idx, chipName in ipairs(raidChipsList) do
    local cBtn = Instance.new("TextButton")
    cBtn.Size = UDim2.new(1, -6, 0, 28)
    cBtn.Text = "     " .. chipName .. " Chip"
    cBtn.TextXAlignment = Enum.TextXAlignment.Left
    cBtn.Font = Enum.Font.Gotham
    cBtn.TextSize = 11
    cBtn.LayoutOrder = idx
    cBtn.Parent = raidListScroll
    addCorner(cBtn, 6)

    if chipName == selectedRaidChip then
        cBtn.BackgroundColor3 = BANANA_YELLOW
        cBtn.TextColor3 = BANANA_TEXT_ON
    else
        cBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        cBtn.TextColor3 = Color3.fromRGB(160, 160, 170)
    end

    cBtn.MouseButton1Click:Connect(function()
        selectedRaidChip = chipName
        _G.SelectChip = chipName
        raidTitle.Text = "🔥 Select Raid Chip: " .. selectedRaidChip
        for name, btn in pairs(chipBtns) do
            if name == selectedRaidChip then
                btn.BackgroundColor3 = BANANA_YELLOW
                btn.TextColor3 = BANANA_TEXT_ON
            else
                btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                btn.TextColor3 = Color3.fromRGB(160, 160, 170)
            end
        end
    end)
    chipBtns[chipName] = cBtn
end
raidListScroll.CanvasSize = UDim2.new(0, 0, 0, #raidChipsList * 32)

createToggleFeature(raidPage, "AutoBuyChipToggle", "Auto Buy Chip", "Automatically buy the selected Raid Chip", 2, autoBuyChipEnabled, function(state)
    autoBuyChipEnabled = state
    _G.AutoBuyChip = state
end)

createToggleFeature(raidPage, "AutoStartRaidToggle", "Auto Start Raid", "Automatically press the Raid start button", 3, autoStartRaidEnabled, function(state)
    autoStartRaidEnabled = state
    _G.StartRaid = state
end)

createToggleFeature(raidPage, "AutoRaidToggle", "Auto Raid", "Automatically defeat mobs and travel between Raid islands", 4, autoRaidEnabled, function(state)
    autoRaidEnabled = state
    _G.Dungeon = state
    -- TÍCH HỢP: bật Auto Raid = tự bật luôn Auto Buy Chip + Auto Start Raid (hiện rõ ô tick); tắt thì tắt cả 3.
    autoBuyChipEnabled, _G.AutoBuyChip = state, state
    autoStartRaidEnabled, _G.StartRaid = state, state
    if toggleUpdateFuncs["AutoBuyChipToggle"] then toggleUpdateFuncs["AutoBuyChipToggle"](state) end
    if toggleUpdateFuncs["AutoStartRaidToggle"] then toggleUpdateFuncs["AutoStartRaidToggle"](state) end
    if state then
        if toggleUpdateFuncs["AutoFarmTargetToggle"] then toggleUpdateFuncs["AutoFarmTargetToggle"](false) end
        if toggleUpdateFuncs["AutoFarmMaterialToggle"] then toggleUpdateFuncs["AutoFarmMaterialToggle"](false) end
        if toggleUpdateFuncs["AutoFarmBossToggle"] then toggleUpdateFuncs["AutoFarmBossToggle"](false) end
        autoFarmEnabled = false
        autoFarmMaterialEnabled = false
        if _G.MHRaidFixed then _G.MHRaidFixed.completed = false end
    end
end)

createToggleFeature(raidPage, "RaidKillAuraToggle", "Raid Kill Aura", "Islands 4 and 5: gather and reset all Raid mobs at once", 5, _G.RaidKillAura, function(state)
    _G.RaidKillAura = state
end)

if World2 then
    createToggleFeature(raidPage, "AutoLawRaidToggle", "Auto Law Raid", "Automatically fight the Order (Law) Boss", 6, _G.AutoLawRaid, function(state)
        _G.AutoLawRaid = state
    end)
end

_G.MinhHubLoad(38, "Loading Auto Raid...")
-- =========================================================
--   RAID: AUTO BUY CHIP / AUTO START RAID / AUTO FARM RAID
--   Hỗ trợ Sea 2 + Sea 3 (BẢN FIX)
-- =========================================================
-- ĐÃ FIX:
-- 1) Mua chip: gửi đúng TÊN CHIP server yêu cầu
--    (Spider -> String, Buddha -> Human: Buddha, Phoenix -> Bird: Phoenix).
--    Bỏ lệnh "Check" thừa, không mua thêm chip khi Raid đang chạy.
-- 2) Start Raid: vòng lặp Farm Raid không còn huỷ chuyến bay của Auto Start Raid.
--    Sea 3: requestEntrance (nếu đang ở xa) -> bay tới Boat Castle -> áp sát nút
--    -> click RaidSummon2. Giữ nhân vật lơ lửng khi chờ/click (không rơi xuyên map).
-- 3) Farm Raid: tự trang bị vũ khí (_G.EquipWeapon), bay tới quái gần nhất,
--    xoay vòng các đảo khi chưa có quái. Mọi vòng lặp có pcall để không chết thread.
-- 4) AUTO RAID KIỂU VIDEO (Banana Cat Hub): chọn chip -> tick "Auto Raid" là xong, 1 công tắc làm hết:
--    mua chip -> Start Raid TỪ XA (nhân vật đứng yên, KHÔNG bay tới phòng Raid) -> "Loading map..."
--    -> server tự dịch chuyển vào đảo Raid -> 3-2-1-GO -> diệt quái từng đảo -> xong thì lặp lại.
--    * Start từ xa = bắn click lên nút RaidSummon2 (fireclickdetector). Nếu server không nhận
--      (nút chưa tải / executor không hỗ trợ) thì TỰ ĐỘNG quay về cách cũ: bay tới phòng Raid rồi bấm.
--      Tắt hẳn Start từ xa: _G.RaidRemoteStart = false.
--    * Cửa sổ "Loading map...": từ lúc server nhận chip tới khi Timer Raid hiện, Raid được coi là ĐANG CHẠY
--      -> không mua chip thừa, không Start lần 2, không đánh nhầm quái thường quanh chỗ đứng.
local RAID_FIXED = {
    debug = true,
    buyCooldown = 4,
    startCooldown = 4,
    -- Tự retry tìm nút / chip để tránh kẹt khi map load chậm.
    arrivalDistance = 7,
    detectorWaitTimeout = 10,
    clickRetries = 4,
    islandHeight = 35, -- fallback; vị trí farm thực tế đọc RAID_FIXED.height()
    lockHeight = 35,   -- bằng độ cao farm thường để Fast Attack luôn trong tầm đánh
    session = 0,
    running = false,
    starting = false,
    buying = false,
    flying = false,
    flightToken = 0,
    nextBuyAt = 0,
    nextStartAt = 0,
    currentIsland = 0,
    lastStatus = "Idle",
    activeReason = nil,
    killAuraActive = false,
    killAuraRadius = 200,     -- tầm Fast Attack khi Kill Aura
    killAuraMaxTargets = 15,  -- số quái đánh cùng lúc khi Kill Aura
    auraConnection = nil,
    auraHoldCF = nil,
    auraIsland = 0,
    auraGroundY = 0,
    baseReady = false,
    baseIslands = {},
    entered = false,      -- đã thật sự vào map Raid (đứng gần đảo Raid) trong lượt Raid này
    mapRadius = 1200,      -- bán kính (studs) quanh đảo Raid được tính là "đã vào map Raid"
    flightTween = nil,
    lockConnection = nil,
    lockEnemy = nil,
    noclipConnection = nil,
    noclipEnabled = false,
    holdConnection = nil,
    holdCF = nil,
    -- ===== AUTO RAID KIỂU VIDEO: Start Raid từ xa + cửa sổ "Loading map..." =====
    remoteStart = true,       -- Start Raid TỪ XA (không bay tới phòng Raid). Tắt: _G.RaidRemoteStart = false
    remoteStartTries = 2,     -- số lần bấm từ xa trước khi chuyển sang cách bay tới nút
    remoteStartWait = 3.5,    -- chờ server nhận chip sau mỗi lần bấm (giây)
    remoteFails = 0,          -- số lần Start từ xa liên tiếp bị server bỏ qua
    remoteBlockedUntil = 0,   -- quá 2 lần liên tiếp thất bại -> tạm dùng cách bay tới nút tới mốc này
    pendingUntil = 0,         -- server đã nhận chip ("Loading map...") -> coi như Raid ĐANG CHẠY tới mốc này
    pendingWindow = 60,       -- tối đa (giây) từ lúc Start tới lúc Timer Raid hiện (video: ~17s tới "GO!")
    pendingStartPos = nil,    -- vị trí nhân vật lúc Start (để biết server đã dịch chuyển vào map Raid chưa)
    pendingStartAt = 0,
    masterWasOn = false,      -- trạng thái "Auto Raid" ở vòng điều khiển trước (đồng bộ Buy Chip / Start Raid)
}
_G.MHRaidFixed = RAID_FIXED

-- Độ cao đứng trên quái khi Raid: THEO thanh "Độ cao Farm" (trước đây cố định 35, kéo thanh không có tác dụng)
function RAID_FIXED.height()
    -- Đọc trực tiếp giá trị thanh Farm Height; cho phép đặt 0 để farm sát mục tiêu.
    local h = tonumber(farmDistanceHeight)
    if h == nil then h = tonumber(RAID_FIXED.lockHeight) or 35 end
    return math.clamp(h, 0, 100)
end


-- =========================================================
-- BỘ ĐIỀU PHỐI TÁC VỤ THÔNG MINH (SMART TASK CONTROLLER)
-- Chỉ cho tác vụ ưu tiên cao hơn chiếm quyền điều khiển ở mỗi lượt.
-- Các tính năng được bật nhưng phải nhường sẽ giữ trạng thái ON và tự tiếp tục
-- khi tác vụ ưu tiên cao hơn kết thúc; không tự tắt toggle chỉ vì đang phải chờ.
-- Thứ tự: mua võ > Raid > nhặt trái > Pirate Raid > Elite/Tyrant/Dough
--         > nguyên liệu > Auto Level/Boss > Chest.
-- =========================================================
Q.SmartController = Q.SmartController or {}
Q.SmartController.priorities = {
    melee = 100,
    raid = 90,
    fruit = 80,
    pirate = 75,
    elite = 64,
    tyrant = 63,
    material = 52,
    farm = 50,
    chest = 10,
}
Q.SmartController.labels = {
    melee = "Mua Fighting Style",
    raid = "Raid / Start Raid / mua chip",
    fruit = "Nhặt hoặc xử lý trái",
    pirate = "Pirate Raid",
    elite = "Elite Hunter",
    tyrant = "Tyrant of the Skies",
    material = "Farm nguyên liệu",
    farm = "Auto Level / Boss",
    chest = "Auto Farm Chest",
}

-- Resolve theo thứ tự ưu tiên giảm dần để tránh cấp phát bảng mỗi 0,05 giây.
-- Dough King dùng các tác vụ con có sẵn (farm Material/Cake/Elite), vì vậy chỉ
-- điều phối tác vụ con đang thực sự chạy; không để bộ Dough King chặn chính nó.
function Q.SmartController.resolveSmartTask()
    local name = nil
    if _G.BuyMeleeActive == true or (Q.MeleeShop and Q.MeleeShop.running == true) then
        name = "melee"
    elseif RAID_FIXED.running == true or RAID_FIXED.starting == true or RAID_FIXED.buying == true
        or autoRaidEnabled == true or _G.Dungeon == true or _G.AutoLawRaid == true
        or autoStartRaidEnabled == true or _G.StartRaid == true
        or autoBuyChipEnabled == true or _G.AutoBuyChip == true then
        name = "raid"
    elseif _G.FruitPickupBusy == true then
        name = "fruit"
    elseif _G.PirateRaidBusy == true then
        name = "pirate"
    elseif _G.EliteBusy == true or _G.EliteHunter == true then
        name = "elite"
    elseif _G.TyrantFarm == true or _G.TyrantSummon == true then
        name = "tyrant"
    elseif autoFarmMaterialEnabled == true then
        name = "material"
    elseif autoFarmEnabled == true then
        name = "farm"
    elseif autoChestEnabled == true then
        name = "chest"
    end

    Q.SmartController.activeTask = name
    Q.SmartController.activeLabel = name and Q.SmartController.labels[name] or "Đang chờ"
    _G.MinhHubActiveTask = name or "idle"
    _G.MinhHubActiveTaskLabel = Q.SmartController.activeLabel
    return name
end

function Q.SmartController.getActiveTask()
    return Q.SmartController.resolveSmartTask()
end

function Q.SmartController.getStatus()
    Q.SmartController.resolveSmartTask()
    return Q.SmartController.activeLabel
end

function Q.SmartController.canRun(taskName)
    taskName = tostring(taskName or "")
    local priorities = Q.SmartController.priorities
    local taskPriority = priorities[taskName]
    if not taskPriority then return false end
    local activeTask = Q.SmartController.resolveSmartTask()
    if not activeTask or activeTask == taskName then return true end
    return taskPriority > (priorities[activeTask] or 0)
end

do
-- Tên hiển thị trong menu -> tên chip server nhận (thử lần lượt)
local RAID_CHIP_SERVER_NAMES = {
    ["Flame"]   = {"Flame"},
    ["Ice"]     = {"Ice"},
    ["Quake"]   = {"Quake"},
    ["Light"]   = {"Light"},
    ["Dark"]    = {"Dark"},
    ["Spider"]  = {"String", "Spider"},
    ["Rumble"]  = {"Rumble"},
    ["Magma"]   = {"Magma"},
    ["Buddha"]  = {"Human: Buddha", "Buddha"},
    ["Sand"]    = {"Sand"},
    ["Dough"]   = {"Dough"},
    ["Phoenix"] = {"Bird: Phoenix", "Phoenix"},
}

local function raidFarmEnabled()
    return (autoRaidEnabled or _G.Dungeon) and true or false
end

-- Start Raid được phép chạy độc lập hoặc cùng với Auto Farm Raid.
local function raidStartEnabled()
    -- FIX: bật Auto Raid mà không bật Auto Start Raid thì script chỉ đứng chờ và không bao giờ vào Raid.
    -- Mặc định TÁCH RIÊNG (Auto Raid chỉ farm). Đặt _G.RaidAutoStart = true nếu muốn Auto Raid tự kèm Start Raid.
    return (autoStartRaidEnabled or _G.StartRaid or (_G.RaidAutoStart == true and raidFarmEnabled())) and true or false
end

-- FIX: raid xong thì Special Microchip bị dùng hết; Auto Raid mà không bật Auto Buy Chip thì raid tiếp bị kẹt
-- ("No Special Microchip"). Mặc định TÁCH RIÊNG. Đặt _G.RaidAutoBuy = true nếu muốn Auto Raid tự kèm Auto Buy Chip.
local function raidBuyEnabled()
    return (autoBuyChipEnabled or _G.AutoBuyChip or (_G.RaidAutoBuy == true and raidFarmEnabled())) and true or false
end

local function raidLog(...)
    if RAID_FIXED.debug then
        print("[RaidFix]", ...)
    end
end

local function getPlayerRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getCommF()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    return remotes and remotes:FindFirstChild("CommF_")
end

-- RAID NOCLIP: chỉ áp dụng trong lúc Raid/Start Raid đang điều khiển nhân vật.
local function setRaidNoclip(state)
    RAID_FIXED.noclipEnabled = state == true

    if state then
        if RAID_FIXED.noclipConnection then return end

        RAID_FIXED.noclipConnection = RunService.Stepped:Connect(function()
            if not RAID_FIXED.noclipEnabled then return end

            local character = LocalPlayer.Character
            if not character then return end

            -- Chống rơi xuyên map khi noclip (huỷ trọng lực bằng BodyVelocity = 0)
            local root0 = character:FindFirstChild("HumanoidRootPart")
            if root0 and not root0:FindFirstChild("BananaAntiFall") then
                local bv = Instance.new("BodyVelocity")
                bv.Name = "BananaAntiFall"
                bv.Velocity = Vector3.zero
                bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                bv.Parent = root0
            end

            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        pcall(function()
            local root0 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local bv = root0 and root0:FindFirstChild("BananaAntiFall")
            if bv then bv:Destroy() end
        end)
        if RAID_FIXED.noclipConnection then
            pcall(function()
                RAID_FIXED.noclipConnection:Disconnect()
            end)
            RAID_FIXED.noclipConnection = nil
        end
    end
end

local function restoreCharacterCollision()
    local character = LocalPlayer.Character
    if not character then return end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if part.Name == "HumanoidRootPart" or part.CanCollide == false then
                pcall(function() part.CanCollide = true end)
            end
        end
    end
end

-- GIỮ NHÂN VẬT LƠ LỬNG tại 1 điểm (noclip bật nên nếu không giữ sẽ rơi xuyên map)
local function setRaidHold(cf)
    RAID_FIXED.holdCF = cf

    if cf then
        if RAID_FIXED.holdConnection then return end
        RAID_FIXED.holdConnection = RunService.Heartbeat:Connect(function()
            local c = RAID_FIXED.holdCF
            local hrp = getPlayerRoot()
            if c and hrp then
                hrp.CFrame = c
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end)
    else
        if RAID_FIXED.holdConnection then
            pcall(function()
                RAID_FIXED.holdConnection:Disconnect()
            end)
            RAID_FIXED.holdConnection = nil
        end
    end
end

-- Có Special Microchip trong Backpack / đang cầm trên tay
local function hasSpecialMicrochip()
    local function scan(container)
        if not container then return false end
        if container:FindFirstChild("Special Microchip") then return true end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), "microchip", 1, true) then
                return true
            end
        end
        return false
    end
    return scan(LocalPlayer:FindFirstChild("Backpack")) or scan(LocalPlayer.Character)
end

-- Một số nút Raid không nhận thao tác nếu nhân vật đang cầm Tool.
-- Tạm tháo toàn bộ Tool trước khi mua chip / bấm Start, sau đó Auto Farm sẽ tự equip lại.
local function unequipRaidTools()
    pcall(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:UnequipTools()
        end

        if character then
            for _, obj in ipairs(character:GetChildren()) do
                if obj:IsA("Tool") then
                    obj.Parent = LocalPlayer:FindFirstChild("Backpack") or character
                end
            end
        end
    end)
end

local function getRaidTimer()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    return main and main:FindFirstChild("Timer")
end

local function getRaidLocations()
    local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
    if not worldOrigin then return nil end

    return worldOrigin:FindFirstChild("Locations")
        or worldOrigin:FindFirstChild("Locations", true)
end

local function getRaidIsland(index)
    local locations = getRaidLocations()
    if not locations then return nil end

    local name = "Island " .. tostring(index)
    local isl = locations:FindFirstChild(name) or locations:FindFirstChild(name, true)
    -- FIX Sea 2: map thường có sẵn các "Island N" tĩnh ở xa. Chỉ nhận đảo Raid thật = đảo nằm gần người chơi
    -- (map Raid nhỏ gọn); đảo tĩnh ở xa bị bỏ qua nên không làm sai mục tiêu / điều kiện "đã vào map Raid".
    if isl then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local okPv, cf = pcall(function()
            return isl:IsA("BasePart") and isl.CFrame or isl:GetPivot()
        end)
        if hrp and okPv and cf and (cf.Position - hrp.Position).Magnitude > 4500 then
            return nil
        end
    end
    return isl
end

-- FIX Sea 2: Raid chỉ được coi là "đang chạy" khi Timer thật sự hiện, hoặc xuất hiện "Island N" MỚI
-- (không có sẵn lúc chưa Raid). Chụp baseline các Island có sẵn để không bị báo "Raid đang chạy" giả,
-- vì khi giả thì Auto Buy Chip và Auto Start Raid bị chặn vĩnh viễn.
local function isRaidActive()
    local ok, active = pcall(function()
        local timer = getRaidTimer()
        local timerOn = timer ~= nil and timer.Visible == true

        -- Raid vừa hoàn thành: giữ cờ completed trong lúc nhân vật vẫn còn ở map Raid,
        -- kể cả khi Timer biến mất. Chỉ mở lượt mới sau khi đã rời map (thường do hồi sinh).
        if not timerOn and RAID_FIXED.completed then
            local stillInRaidMap = false
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for i = 1, 8 do
                    local island = getRaidIsland(i)
                    if island then
                        local pos
                        pcall(function()
                            if island:IsA("BasePart") then
                                pos = island.Position
                            else
                                pos = island:GetPivot().Position
                            end
                        end)
                        if pos and (pos - hrp.Position).Magnitude <= (tonumber(RAID_FIXED.mapRadius) or 1200) then
                            stillInRaidMap = true
                            break
                        end
                    end
                end
            end
            if not stillInRaidMap then RAID_FIXED.completed = false end
        end
        if RAID_FIXED.completed then
            RAID_FIXED.activeReason = nil
            RAID_FIXED.activeSince = nil
            RAID_FIXED.entered = false
            return false
        end
        local locations = getRaidLocations()

        if locations and not timerOn and not RAID_FIXED.baseReady then
            for i = 1, 8 do
                local baseIsl = locations:FindFirstChild("Island " .. i)
                if baseIsl then
                    RAID_FIXED.baseIslands[i] = baseIsl
                end
            end
            RAID_FIXED.baseReady = true
        end

        if timerOn then
            RAID_FIXED.activeReason = "Timer"
            RAID_FIXED.wasActive = true
            return true
        end

        if locations then
            for i = 1, 8 do
                local curIsl = locations:FindFirstChild("Island " .. i)
                local baseInst = RAID_FIXED.baseIslands[i]
                -- đảo cũ đã biến mất / bị thay bằng đảo mới (Raid mới) -> không còn bị bỏ qua
                if baseInst and (typeof(baseInst) ~= "Instance" or not baseInst.Parent or baseInst ~= curIsl) then
                    RAID_FIXED.baseIslands[i] = nil
                    baseInst = nil
                end
                local isl = (not baseInst) and curIsl
                if isl then
                    -- FIX: đảo còn sót lại sau Raid (không có Timer / quái / người chơi gần) làm Raid bị báo "đang chạy"
                    -- vĩnh viễn -> Auto Buy Chip & Auto Start Raid bị chặn. Cần có bằng chứng Raid thật.
                    local pos
                    pcall(function() pos = isl:IsA("BasePart") and isl.Position or isl:GetPivot().Position end)
                    local evidence = false
                    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if pos and myHrp and (myHrp.Position - pos).Magnitude <= 1200 then evidence = true end
                    if pos and not evidence then
                        local ef = workspace:FindFirstChild("Enemies")
                        if ef then
                            for _, m in ipairs(ef:GetChildren()) do
                                local mh = m:FindFirstChild("HumanoidRootPart")
                                if mh and (mh.Position - pos).Magnitude <= 650 then evidence = true break end
                            end
                        end
                    end
                    if evidence then
                        RAID_FIXED.staleSince = nil
                        RAID_FIXED.wasActive = true
                        RAID_FIXED.activeReason = "Island " .. i
                        return true
                    end
                    RAID_FIXED.staleSince = RAID_FIXED.staleSince or tick()
                    if tick() - RAID_FIXED.staleSince > 8 then
                        RAID_FIXED.baseIslands[i] = isl   -- đảo sót: bỏ qua (theo đúng instance này)
                        RAID_FIXED.staleSince = nil
                    else
                        RAID_FIXED.activeReason = "Island " .. i .. " (chờ xác nhận)"
                        return true
                    end
                end
            end
        end

        RAID_FIXED.activeReason = nil
        RAID_FIXED.activeSince = nil
        RAID_FIXED.entered = false -- Raid kết thúc -> lượt sau phải vào map lại mới farm
        -- FIX: đảo còn sót sau raid bị đánh dấu "đảo tĩnh" mãi mãi -> raid sau nhận diện sai. Chụp lại baseline từ đầu.
        if RAID_FIXED.wasActive then
            RAID_FIXED.wasActive = false
            RAID_FIXED.baseIslands = {}
            RAID_FIXED.baseReady = false
            RAID_FIXED.staleSince = nil
            RAID_FIXED.nextStartAt = 0
            RAID_FIXED.nextBuyAt = 0
        end
        return false
    end)
    return ok and active == true
end

local function getPivotPosition(obj)
    if not obj then return nil end
    local ok, cf = pcall(function()
        if obj:IsA("BasePart") then
            return obj.CFrame
        end
        return obj:GetPivot()
    end)
    return ok and cf or nil
end

-- FIX: chỉ coi là "đã vào map Raid" khi nhân vật thật sự đứng gần một đảo Raid
-- (server đã dịch chuyển người chơi vào). Trả về: đã vào map?, khoảng cách tới đảo gần nhất.
local function isInRaidMap()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, math.huge end

    local best = math.huge
    for i = 1, 8 do
        local cf = getPivotPosition(getRaidIsland(i))
        if cf then
            local d = (cf.Position - hrp.Position).Magnitude
            if d < best then best = d end
        end
    end
    return best <= RAID_FIXED.mapRadius, best
end

local function cancelRaidFlight()
    RAID_FIXED.flightToken += 1
    RAID_FIXED.flying = false

    if RAID_FIXED.flightTween then
        pcall(function()
            RAID_FIXED.flightTween:Cancel()
        end)
        RAID_FIXED.flightTween = nil
    end

    local hrp = getPlayerRoot()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

-- Bay một chuyến duy nhất tới mục tiêu. Trả về true nếu tới nơi.
local function raidFlyTo(targetCFrame, speed, keepGoing)
    local hrp = getPlayerRoot()
    if not hrp then return false end

    -- FIX Thuyền Ma (Sea 2): Start Raid / Buy Chip / Farm Raid đang ở trong Thuyền Ma (~922.9, 128.4, 32841.9)
    -- thì không được tween thẳng ra đảo Raid (cách ~30000 studs, rơi xuyên map / kẹt).
    -- Dùng chung bộ điều phối cổng Q.enterIfNeeded (bay tới cổng + requestEntrance) để THOÁT thuyền trước.
    if World2 and Q and Q.enterIfNeeded then
        local function inCursedShip(pos)
            return Q.isCursedShipPosition(pos)
        end
        local targetInShip = inCursedShip(targetCFrame.Position)
        local deadline = tick() + 45
        while tick() < deadline do
            if keepGoing and not keepGoing() then return false end
            local root = getPlayerRoot()
            if not root then return false end
            if inCursedShip(root.Position) == targetInShip then break end

            local okT, busy = pcall(Q.enterIfNeeded, root, targetCFrame.Position, "raid")
            if not okT then
                RAID_FIXED.lastStatus = "Lỗi khi qua cổng Thuyền Ma: " .. tostring(busy)
                return false
            end
            if not busy then break end
            task.wait(0.3)
        end
        hrp = getPlayerRoot()
        if not hrp then return false end
        -- Không được tiếp tục tween khoảng cách xa nếu cổng chưa chuyển nhân vật sang đúng phía.
        if inCursedShip(hrp.Position) ~= targetInShip then
            RAID_FIXED.lastStatus = "Chưa thoát Thuyền Ma được; tạm dừng bay Raid để tránh kẹt/xuyên map"
            return false
        end
    end

    -- Raid flight dùng cùng tốc độ Farm (đọc flySpeed tại thời điểm bay).
    local spd = math.clamp(tonumber(speed or flySpeed) or 190, 60, 350)

    setRaidNoclip(true)
    setRaidHold(nil) -- thôi giữ vị trí cũ để không tranh quyền với Tween

    if RAID_FIXED.flightTween then
        pcall(function()
            RAID_FIXED.flightTween:Cancel()
        end)
        RAID_FIXED.flightTween = nil
    end

    RAID_FIXED.flightToken += 1
    local myToken = RAID_FIXED.flightToken
    RAID_FIXED.flying = true

    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    if distance <= RAID_FIXED.arrivalDistance then
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        RAID_FIXED.flying = false
        return true
    end

    local duration = math.max(0.12, distance / spd)
    local deadline = tick() + duration + 3

    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        {CFrame = targetCFrame}
    )
    RAID_FIXED.flightTween = tween
    tween:Play()

    while myToken == RAID_FIXED.flightToken and tick() < deadline do
        if keepGoing and not keepGoing() then
            break
        end

        if not hrp.Parent then
            break
        end

        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        local st = tween.PlaybackState
        if st == Enum.PlaybackState.Completed or st == Enum.PlaybackState.Cancelled then
            break
        end

        RunService.Heartbeat:Wait()
    end

    local currentRoot = getPlayerRoot()
    local reached = currentRoot ~= nil
        and (tween.PlaybackState == Enum.PlaybackState.Completed
            or (currentRoot.Position - targetCFrame.Position).Magnitude <= 12)

    if tween.PlaybackState == Enum.PlaybackState.Playing then
        pcall(function()
            tween:Cancel()
        end)
    end

    if myToken == RAID_FIXED.flightToken then
        currentRoot = getPlayerRoot()

        if currentRoot and reached then
            currentRoot.CFrame = targetCFrame
            currentRoot.AssemblyLinearVelocity = Vector3.zero
            currentRoot.AssemblyAngularVelocity = Vector3.zero
        end

        RAID_FIXED.flightTween = nil
        RAID_FIXED.flying = false
    else
        return false
    end

    return reached == true
end

local function getRaidRoomTarget()
    if World2 then
        return CFrame.new(-6438.73535, 250.645355, -4501.50684)
    elseif World3 then
        return CFrame.new(
            -5017.40869, 314.844055, -2823.0127,
            -0.925743818, 4.48217499e-08, -0.378151238,
             4.55503146e-09, 1, 1.07377559e-07,
             0.378151238, 9.7681621e-08, -0.925743818
        )
    end
    return nil
end

local function findRaidSummonDetector()
    local map = workspace:FindFirstChild("Map")
    if not map then return nil end

    -- Ưu tiên chính xác theo từng Sea.
    local directSummon
    if World2 then
        local circle = map:FindFirstChild("CircleIsland")
        directSummon = circle and circle:FindFirstChild("RaidSummon2")
    elseif World3 then
        local boat = map:FindFirstChild("Boat Castle")
        directSummon = boat and boat:FindFirstChild("RaidSummon2")
    end

    if directSummon then
        local button = directSummon:FindFirstChild("Button")
        local main = button and button:FindFirstChild("Main")
        local detector = main and main:FindFirstChildOfClass("ClickDetector")
        if detector then
            return detector
        end

        detector = directSummon:FindFirstChildWhichIsA("ClickDetector", true)
        if detector then return detector end
    end

    -- Fallback: cấu trúc map có thể thay đổi nhẹ. Chỉ chấp nhận ClickDetector
    -- có tổ tiên mang tên RaidSummon2 để tránh bấm nhầm nút khác.
    local scope = (World3 and map:FindFirstChild("Boat Castle"))
        or (World2 and map:FindFirstChild("CircleIsland"))
        or map

    if RAID_FIXED._detCache and RAID_FIXED._detCache.Parent then return RAID_FIXED._detCache end
    if tick() - (RAID_FIXED._detScanAt or 0) < 3 then return nil end   -- không quét map quá 1 lần / 3s
    RAID_FIXED._detScanAt = tick()
    for _, obj in ipairs(scope:GetDescendants()) do
        if obj:IsA("ClickDetector") then
            local parent = obj.Parent
            for _ = 1, 8 do
                if not parent then break end
                if parent.Name == "RaidSummon2" then
                    RAID_FIXED._detCache = obj
                    return obj
                end
                parent = parent.Parent
            end
        end
    end

    return nil
end

-- InvokeServer có timeout: nếu server không trả lời thì không bị treo vĩnh viễn
local function invokeRemote(remote, timeout, ...)
    local args = table.pack(...)
    local done, ok, res = false, false, nil
    _G.MHSpawn(function()
        ok, res = pcall(function()
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end)
        done = true
    end)
    local deadline = tick() + (timeout or 5)
    while not done and tick() < deadline do
        task.wait(0.05)
    end
    return done and ok, res
end

local function prepareRaidRoom()
    local commF = getCommF()
    local target = getRaidRoomTarget()
    if not commF or not target then
        return false, "Không xác định được phòng Raid"
    end

    local hrp = getPlayerRoot()
    if not hrp then
        return false, "Chưa có nhân vật"
    end

    -- Quan trọng: bỏ Tool trước khi bấm nút Start Raid.
    unequipRaidTools()
    task.wait(0.1)

    -- FIX Sea 2: đảo Raid ở rất xa, nút RaidSummon2 chưa được tải (StreamingEnabled) nên không tìm thấy.
    -- Yêu cầu server stream map quanh phòng Raid trước khi bay tới.
    _G.MHSpawn(function()
        pcall(function() LocalPlayer:RequestStreamAroundAsync(target.Position) end)
    end)

    setRaidNoclip(true)

    -- Tắt tween/farm chung đang chạy để không tranh quyền điều khiển HRP.
    cancelFarmTween()
    if currentRaidTween then
        pcall(function() currentRaidTween:Cancel() end)
        currentRaidTween = nil
    end

    -- Nếu nút Raid đã load sẵn, lấy chính vị trí của nút làm mục tiêu;
    -- nếu chưa load thì dùng tọa độ dự phòng theo Sea.
    local detector = findRaidSummonDetector()
    if detector and detector.Parent and detector.Parent:IsA("BasePart") then
        target = CFrame.new(detector.Parent.Position + Vector3.new(0, 4, 0))
    elseif World3 and (hrp.Position - target.Position).Magnitude > 600 then
        RAID_FIXED.lastStatus = "Sea 3: requestEntrance..."
        invokeRemote(commF, 5, "requestEntrance", Vector3.new(-5075.50927734375, 314.5155029296875, -3150.0224609375))
        task.wait(0.6)

        detector = findRaidSummonDetector()
        if detector and detector.Parent and detector.Parent:IsA("BasePart") then
            target = CFrame.new(detector.Parent.Position + Vector3.new(0, 4, 0))
        end
    end

    RAID_FIXED.lastStatus = World3 and "Sea 3: tới phòng Raid" or "Sea 2: tới phòng Raid"
    local ok = raidFlyTo(target, flySpeed, raidStartEnabled)
    if not ok then
        return false, "Bay tới phòng Raid bị gián đoạn"
    end

    -- Giữ nhân vật đứng yên trong lúc chờ nút / click.
    setRaidHold(target)

    -- Đặt spawn point sau khi đã tới phòng.
    invokeRemote(commF, 5, "SetSpawnPoint")

    task.wait(0.35)
    return true, "Reached the Raid room"
end


-- Mua chip: gửi đúng tên chip server nhận, chờ chip vào Backpack.
-- Lần 1 mua từ xa. Nếu không nhận được chip (một số bản Sea 2 bắt phải đứng gần NPC Raid)
-- thì bay tới phòng Raid rồi mua lại.
local function buySelectedRaidChip()
    if not (World2 or World3) then
        return false, "Raid chỉ hỗ trợ Sea 2/Sea 3"
    end

    -- KHÓA CỨNG: dù Timer/remote có báo sai, đang đứng trong map Raid thì tuyệt đối không mua chip.
    -- Chỉ cho mua lượt kế tiếp sau khi farm xong và nhân vật rời khỏi map Raid.
    local inRaidMapNow = isInRaidMap()
    if inRaidMapNow then
        RAID_FIXED.lastStatus = "Đang ở trong map Raid - khóa mua chip đến khi Raid hoàn thành"
        return false, RAID_FIXED.lastStatus
    end
    if RAID_FIXED.running or RAID_FIXED.starting then
        return false, "Raid hiện tại chưa kết thúc - chưa được mua chip mới"
    end
    if hasSpecialMicrochip() then
        return true, "Đã có Special Microchip"
    end
    -- Đang Raid thì KHÔNG mua chip
    local raidRunningNow = false
    if isRaidActive() then
        return false, "Raid đang chạy (" .. tostring(RAID_FIXED.activeReason) .. ")"
    end
    if RAID_FIXED.buying then
        return false, "Đang mua chip..."
    end
    if tick() < RAID_FIXED.nextBuyAt then
        return false, "Đang chờ cooldown mua chip"
    end

    local commF = getCommF()
    if not commF then
        return false, "Không tìm thấy Remotes.CommF_"
    end

    RAID_FIXED.buying = true
    RAID_FIXED.buyingAt = tick()
    RAID_FIXED.nextBuyAt = tick() + (raidRunningNow and 15 or RAID_FIXED.buyCooldown)

    local selected = selectedRaidChip or _G.SelectChip or "Flame"
    local serverNames = RAID_CHIP_SERVER_NAMES[selected] or {selected}
    local lastReply = nil

    local function tryBuy()
        for _, serverName in ipairs(serverNames) do
            if hasSpecialMicrochip() then return true end
            if isInRaidMap() or isRaidActive() then
                RAID_FIXED.lastStatus = "Đã phát hiện Raid/map Raid - hủy thao tác mua chip"
                return false
            end

            RAID_FIXED.lastStatus = "Đang mua " .. tostring(selected) .. " Chip (" .. tostring(serverName) .. ")"
            local okSelect, reply = invokeRemote(commF, 6, "RaidsNpc", "Select", serverName)
            raidLog("RaidsNpc Select", serverName, okSelect, reply)
            if reply ~= nil then lastReply = reply end

            local deadline = tick() + 3
            repeat
                task.wait(0.1)
            until hasSpecialMicrochip() or tick() >= deadline

            if hasSpecialMicrochip() then return true end
        end
        return false
    end

    local okRun, gotChip = pcall(function()
        if tryBuy() then return true end

        -- Lần 2: bay tới NPC/phòng Raid rồi mua lại.
        local target = getRaidRoomTarget()
        local root = getPlayerRoot()
        if not raidRunningNow and not isInRaidMap() and not isRaidActive()
            and target and root and (root.Position - target.Position).Magnitude > 150
            and raidBuyEnabled() then
            RAID_FIXED.lastStatus = "Bay tới NPC Raid để mua chip..."
            _G.MHSpawn(function()
                pcall(function() LocalPlayer:RequestStreamAroundAsync(target.Position) end)
            end)
            local arrived = raidFlyTo(target, flySpeed, function()
                return raidBuyEnabled() and not isRaidActive() and not isInRaidMap()
            end)
            if arrived then
                setRaidHold(target)
                task.wait(0.5)
                local got = tryBuy()
                if not raidFarmEnabled() then
                    setRaidHold(nil)
                    setRaidNoclip(false)
                    restoreCharacterCollision()
                end
                return got
            end
            if not raidFarmEnabled() then
                setRaidHold(nil)
                setRaidNoclip(false)
                restoreCharacterCollision()
            end
        end
        return false
    end)

    RAID_FIXED.buying = false -- luôn nhả cờ, kể cả khi lỗi

    if okRun and gotChip then
        RAID_FIXED.lastStatus = "Special Microchip received"
        return true, "Special Microchip received"
    end

    local msg = "Chưa nhận được chip (kiểm tra Beli/Fragments)"
    if lastReply ~= nil then
        msg = msg .. " | Server: " .. tostring(lastReply)
    end
    return false, msg
end

-- Nhả quyền điều khiển nếu không còn chế độ Farm Raid.
local function releaseRaidControl()
    if not raidFarmEnabled() then
        setRaidHold(nil)
        setRaidNoclip(false)
        restoreCharacterCollision()
    end
end

local function clickRaidSummon()
    if not (World2 or World3) then
        return false, "Không ở Sea 2/Sea 3"
    end

    -- KHÓA CỨNG: không được kích hoạt Raid mới khi nhân vật còn ở map Raid hiện tại.
    if isInRaidMap() then
        RAID_FIXED.lastStatus = "Đang trong map Raid - phải farm xong và rời map mới Start Raid tiếp"
        return false, RAID_FIXED.lastStatus
    end
    if RAID_FIXED.running then
        return false, "Raid hiện tại vẫn đang farm - chưa thể Start Raid mới"
    end

    if isRaidActive() then
        return true, "Raid đang chạy"
    end

    if not hasSpecialMicrochip() then
        return false, "No Special Microchip"
    end

    if not raidStartEnabled() then
        return false, "Auto Start Raid đang tắt"
    end

    if RAID_FIXED.starting then
        return false, "Đang Start Raid..."
    end

    if tick() < RAID_FIXED.nextStartAt then
        return false, "Đang chờ cooldown Start Raid"
    end

    RAID_FIXED.starting = true
    RAID_FIXED.startingAt = tick()
    RAID_FIXED.nextStartAt = tick() + RAID_FIXED.startCooldown
    local mySession = RAID_FIXED.session

    local function sessionOk()
        return mySession == RAID_FIXED.session
    end

    local function doStart()
        if isInRaidMap() then
            return false, "Đã ở trong map Raid - không Start lượt mới"
        end
        local roomOk, roomMsg = prepareRaidRoom()
        if not roomOk then
            return false, roomMsg
        end
        if isInRaidMap() then
            return false, "Nhân vật đã vào map Raid - hủy Start lượt mới"
        end

        local detector
        local detectorDeadline = tick() + RAID_FIXED.detectorWaitTimeout
        repeat
            if not sessionOk() then return false, "Nhân vật đã hồi sinh" end
            if isInRaidMap() then return false, "Đã vào map Raid - không Start lượt mới" end
            detector = findRaidSummonDetector()
            if detector or isRaidActive() or not raidStartEnabled() then break end
            task.wait(0.5)
        until tick() >= detectorDeadline

        if isRaidActive() then
            RAID_FIXED.lastStatus = "Raid started"
            return true, "Raid đang chạy"
        end

        if not raidStartEnabled() then
            return false, "Đã tắt Start Raid"
        end

        if not detector then
            -- Thử đọc chính xác đường dẫn lần cuối sau khi map đã load.
            if World2 then
                local d = workspace:FindFirstChild("Map")
                    and workspace.Map:FindFirstChild("CircleIsland")
                    and workspace.Map.CircleIsland:FindFirstChild("RaidSummon2")
                detector = d and d:FindFirstChild("Button")
                    and d.Button:FindFirstChild("Main")
                    and d.Button.Main:FindFirstChildOfClass("ClickDetector")
            elseif World3 then
                local d = workspace:FindFirstChild("Map")
                    and workspace.Map:FindFirstChild("Boat Castle")
                    and workspace.Map["Boat Castle"]:FindFirstChild("RaidSummon2")
                detector = d and d:FindFirstChild("Button")
                    and d.Button:FindFirstChild("Main")
                    and d.Button.Main:FindFirstChildOfClass("ClickDetector")
            end
        end

        if not detector then
            return false, "Không tìm thấy RaidSummon2 (map chưa tải - đứng gần phòng Raid)"
        end
        if typeof(fireclickdetector) ~= "function" and not (okVIM and VirtualInputManager) then
            return false, "Executor không hỗ trợ fireclickdetector/VirtualInputManager -> không bấm được nút Start"
        end

        -- Áp sát nút để nằm trong tầm ClickDetector.
        local buttonPart = detector.Parent
        if buttonPart and buttonPart:IsA("BasePart") then
            local root = getPlayerRoot()
            if root and (root.Position - buttonPart.Position).Magnitude > 10 then
                local nearCF = CFrame.new(buttonPart.Position + Vector3.new(0, 4, 0))
                if raidFlyTo(nearCF, flySpeed, raidStartEnabled) then
                    setRaidHold(nearCF)
                end
            end
        end

        -- Nút Start có thể bị từ chối nếu đang cầm vũ khí / Tool.
        unequipRaidTools()
        task.wait(0.15)

        RAID_FIXED.completed = false -- sắp Start raid mới: từ giờ nhận diện theo trạng thái thật
        for attempt = 1, RAID_FIXED.clickRetries do
            if not sessionOk() then return false, "Nhân vật đã hồi sinh" end
            if not raidStartEnabled() then return false, "Đã tắt Start Raid" end
            if isInRaidMap() then return false, "Đã vào map Raid - chặn kích hoạt Raid mới" end
            if isRaidActive() then return true, "Raid đang chạy" end

            -- Detector có thể bị recreate; luôn lấy lại trước từng lần thử.
            detector = findRaidSummonDetector() or detector
            RAID_FIXED.lastStatus = "Start Raid " .. (World3 and "Sea 3" or "Sea 2") .. " lần " .. tostring(attempt)

            local ok, err = pcall(function()
                unequipRaidTools()
                task.wait(0.08)

                -- Làm mới detector ngay trước khi click.
                local fresh = findRaidSummonDetector()
                if fresh then
                    detector = fresh
                end

                -- ClickDetector mặc định (nếu executor hỗ trợ).
                if typeof(fireclickdetector) == "function" then
                    fireclickdetector(detector)
                    task.wait(0.08)
                end

                -- Dự phòng: click thật lên nút bằng chuột ảo (executor không có fireclickdetector,
                -- hoặc lần click đầu không có tác dụng).
                if (typeof(fireclickdetector) ~= "function" or attempt >= 2)
                    and okVIM and VirtualInputManager
                    and detector.Parent and detector.Parent:IsA("BasePart") then
                    local cam = workspace.CurrentCamera
                    local part = detector.Parent
                    if cam then
                        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, part.Position)
                        local v, onScreen = cam:WorldToViewportPoint(part.Position)
                        if onScreen then
                            VirtualInputManager:SendMouseButtonEvent(v.X, v.Y, 0, true, game, 0)
                            task.wait(0.05)
                            VirtualInputManager:SendMouseButtonEvent(v.X, v.Y, 0, false, game, 0)
                        end
                    end
                end

                -- Một số executor/game build nhận tốt hơn khi truyền distance = 0.
                if attempt % 2 == 0 then
                    pcall(function()
                        if typeof(fireclickdetector) == "function" then
                            fireclickdetector(detector, 0)
                        end
                    end)
                end
            end)

            if not ok then
                raidLog("fireclickdetector lỗi:", err)
            else
                local verifyDeadline = tick() + 3
                local chipUsed = false
                while tick() < verifyDeadline do
                    if not sessionOk() then return false, "Nhân vật đã hồi sinh" end
                    if isRaidActive() then
                        RAID_FIXED.lastStatus = "Raid started - " .. (World3 and "Sea 3" or "Sea 2")
                        raidLog("Start Raid thành công:", World3 and "Sea 3" or "Sea 2")
                        return true, "Raid started"
                    end
                    -- Chip biến mất = server đã nhận lệnh -> chờ Raid xuất hiện, KHÔNG click/mua lại
                    if not chipUsed and not hasSpecialMicrochip() then
                        chipUsed = true
                        verifyDeadline = tick() + 25
                        RAID_FIXED.lastStatus = "Server đã nhận chip - chờ Raid xuất hiện..."
                    end
                    task.wait(0.2)
                end
                if chipUsed then break end
            end

            if attempt < RAID_FIXED.clickRetries then
                detector = findRaidSummonDetector() or detector
                task.wait(0.35)
            end
        end

        setRaidHold(nil)
        setRaidNoclip(false)
        restoreCharacterCollision()
        return false, "Đã click nhưng server chưa tạo Raid"
    end

    local okCall, ok, msg = pcall(doStart)
    RAID_FIXED.starting = false

    -- FIX: Start xong phải NHẢ nhân vật ngay. Trước đây setRaidHold(nút Start) vẫn chạy mỗi frame nên
    -- khi server dịch chuyển vào map Raid thì bị kéo ngược về phòng chờ -> kẹt, không farm được.
    if okCall and ok then
        setRaidHold(nil)
        cancelRaidFlight()
    end

    if not okCall then
        msg = "Lỗi Start Raid: " .. tostring(ok)
        ok = false
        raidLog(msg)
    end

    releaseRaidControl()
    return ok, msg
end

local function enemyAlive(enemy)
    if not enemy or not enemy.Parent then return false end
    local hum = enemy:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

-- Đảo Raid có số cao nhất đang tồn tại (Raid đi từ đảo 1 -> 5, không bao giờ quay lại đảo cũ).
local function getHighestRaidIsland()
    for i = 8, 1, -1 do
        local cf = getPivotPosition(getRaidIsland(i))
        if cf then return i, cf end
    end
    return nil, nil
end

-- Quái Raid gần người chơi nhất.
-- islandIdx != nil: CHỈ lấy quái quanh đảo đó (bán kính 650) -> không bị kéo về đảo cũ.
-- islandIdx == nil: lấy quái ở mọi đảo (chỉ dùng để dọn quái sót khi đảo hiện tại trống lâu).
local function getRaidEnemy(islandIdx)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    local hrp = getPlayerRoot()
    if not enemiesFolder or not hrp then return nil end

    local anchors = {}
    local radius = 900
    if islandIdx then
        local cf = getPivotPosition(getRaidIsland(islandIdx))
        if cf then
            anchors[1] = cf.Position
            radius = 650
        end
    else
        for i = 1, 8 do
            local cf = getPivotPosition(getRaidIsland(i))
            if cf then
                anchors[#anchors + 1] = cf.Position
            end
        end
    end

    local lobbyCF = getRaidRoomTarget()
    local nearLobby = lobbyCF ~= nil and (lobbyCF.Position - hrp.Position).Magnitude < 1500
    local best, bestDist = nil, math.huge
    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        local enemyHrp = enemy:FindFirstChild("HumanoidRootPart")
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        if enemyHrp and hum and hum.Health > 0 then
            local inArea = false
            if #anchors == 0 then
                -- không đọc được đảo Raid: chỉ nhận quái gần người chơi khi KHÔNG đứng ở phòng chờ (tránh đánh nhầm quái thường)
                inArea = (not nearLobby) and (enemyHrp.Position - hrp.Position).Magnitude <= 700
            else
                for _, pos in ipairs(anchors) do
                    if (enemyHrp.Position - pos).Magnitude <= radius then
                        inArea = true
                        break
                    end
                end
            end

            if inArea then
                local distPlayer = (enemyHrp.Position - hrp.Position).Magnitude
                if distPlayer < bestDist then
                    bestDist = distPlayer
                    best = enemy
                end
            end
        end
    end
    return best
end

local function stopRaidPositionLock()
    if RAID_FIXED.lockConnection then
        pcall(function()
            RAID_FIXED.lockConnection:Disconnect()
        end)
        RAID_FIXED.lockConnection = nil
    end
    RAID_FIXED.lockEnemy = nil

    local hrp = getPlayerRoot()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

local function startRaidPositionLock(enemy)
    RAID_FIXED.lockEnemy = enemy
    setRaidHold(nil)

    if RAID_FIXED.lockConnection then
        return
    end

    RAID_FIXED.lockConnection = RunService.Heartbeat:Connect(function()
        local lockedEnemy = RAID_FIXED.lockEnemy

        if not (autoRaidEnabled or _G.Dungeon)
            or not isRaidActive()
            or not lockedEnemy
            or not lockedEnemy.Parent
        then
            return
        end

        local currentHrp = getPlayerRoot()
        local liveEnemyHrp = lockedEnemy:FindFirstChild("HumanoidRootPart")
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

        if not currentHrp or not liveEnemyHrp then
            return
        end

        if hum then
            hum.AutoRotate = false
        end

        local livePos = liveEnemyHrp.Position + Vector3.new(0, RAID_FIXED.height(), 0)

        -- FIX: bản cũ dùng CFrame.lookAt(livePos, horizontalTarget) nhưng 2 điểm này TRÙNG NHAU
        -- (đứng ngay trên đầu quái) -> CFrame bị NaN -> nhân vật rơi/chết -> reset liên tục.
        -- Giờ chỉ xoay theo hướng quái, không dùng lookAt nữa.
        local _, yaw, _ = liveEnemyHrp.CFrame:ToOrientation()
        local newCF = CFrame.new(livePos) * CFrame.fromOrientation(0, yaw, 0)
        if newCF.Position ~= newCF.Position then return end -- chặn NaN
        currentHrp.CFrame = newCF
        currentHrp.AssemblyLinearVelocity = Vector3.zero
        currentHrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ===== RAID KILL AURA =====
-- Khi farm tới đảo 4/5: đứng giữa cụm quái, GOM toàn bộ quái Raid của đảo về dưới chân,
-- RESET (giết ngay: Health = 0 + BreakJoints) tất cả quái, đồng thời Fast Attack đánh phụ trợ
-- (phòng khi server không nhận máu đổi từ client).
function RAID_FIXED.stopAura()
    RAID_FIXED.killAuraActive = false
    RAID_FIXED.auraHoldCF = nil
    if RAID_FIXED.auraConnection then
        pcall(function() RAID_FIXED.auraConnection:Disconnect() end)
        RAID_FIXED.auraConnection = nil
    end
end

function RAID_FIXED.startAura()
    RAID_FIXED.killAuraActive = true
    if RAID_FIXED.auraConnection then return end

    RAID_FIXED.auraConnection = RunService.Heartbeat:Connect(function()
        if not RAID_FIXED.killAuraActive then return end
        local hold = RAID_FIXED.auraHoldCF
        local folder = workspace:FindFirstChild("Enemies")
        local isl = getPivotPosition(getRaidIsland(RAID_FIXED.auraIsland))
        if not hold or not folder or not isl then return end

        pcall(function()
            if sethiddenproperty then
                sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
            end
        end)

        local gather = Vector3.new(hold.Position.X, RAID_FIXED.auraGroundY, hold.Position.Z)
        for _, mob in ipairs(folder:GetChildren()) do
            local mh = mob:FindFirstChild("HumanoidRootPart")
            local hum = mob:FindFirstChildOfClass("Humanoid")
            if mh and hum and hum.Health > 0
                and (mh.Position - isl.Position).Magnitude <= 650 then
                pcall(function()
                    mh.CanCollide = false
                    mh.AssemblyLinearVelocity = Vector3.zero
                    mh.AssemblyAngularVelocity = Vector3.zero
                    hum.PlatformStand = true
                    hum.WalkSpeed = 0
                    mh.CFrame = CFrame.new(gather)

                    -- RESET quái: đặt máu về 0 và phá khớp (cần SimulationRadius lớn / quái ở gần mình)
                    if _G.RaidKillAuraReset ~= false then
                        hum.Health = 0
                        mob:BreakJoints()
                    end
                end)
            end
        end
    end)
end

-- ===== HỆ THỐNG QUÉT: ĐANG Ở TRONG RAID CHƯA? =====
-- Kết hợp nhiều dấu hiệu (không chỉ 1):
--   1) Raid đang chạy (Timer hiện / có đảo Raid mới)
--   2) Nhân vật đứng gần một đảo Raid (<= mapRadius)
--   3) Dự phòng: không còn ở phòng chờ và có >= 2 quái đang sống trong 400 studs
-- Trả về: (đã ở trong Raid?, lý do) -> chỉ khi true mới bắt đầu farm.
function RAID_FIXED.scan()
    local hrp = getPlayerRoot()
    if not hrp then return false, "chưa có nhân vật" end

    if not isRaidActive() then return false, "Raid chưa chạy" end

    local inMap, dist = isInRaidMap()
    if inMap then
        return true, string.format("đứng cách đảo Raid %d studs", math.floor(dist))
    end

    local lobby = getRaidRoomTarget()
    local atLobby = lobby ~= nil and (lobby.Position - hrp.Position).Magnitude < 1500

    if not atLobby then
        local folder = workspace:FindFirstChild("Enemies")
        if folder then
            local count = 0
            for _, m in ipairs(folder:GetChildren()) do
                local mh = m:FindFirstChild("HumanoidRootPart")
                local hum = m:FindFirstChildOfClass("Humanoid")
                if mh and hum and hum.Health > 0 and (mh.Position - hrp.Position).Magnitude <= 400 then
                    count = count + 1
                end
            end
            if count >= 2 then
                return true, count .. " quái Raid ở gần"
            end
        end
    end

    return false, atLobby and "đang ở phòng chờ Raid" or "chưa thấy đảo / quái Raid"
end

local function farmRaidIslands()
    if not (World2 or World3) then return false end
    if not raidFarmEnabled() or not isRaidActive() then return false end

    -- Khi Raid started, bỏ Tool Start còn sót rồi Farm mới tự equip lại.
    unequipRaidTools()

    local mySession = RAID_FIXED.session
    local function alive()
        return mySession == RAID_FIXED.session and raidFarmEnabled() and isRaidActive()
    end

    RAID_FIXED.running = true
    setRaidNoclip(true)
    stopRaidPositionLock()
    setRaidHold(nil)

    local raidHumanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local oldAutoRotate = raidHumanoid and raidHumanoid.AutoRotate
    if raidHumanoid then
        raidHumanoid.AutoRotate = false
    end

    local lastEquip, lastEnemySeen, heldIsland = 0, tick(), 0
    local curIsland = 0       -- đảo đang đánh (chỉ tăng, không bao giờ giảm)
    local clearedSince = nil  -- thời điểm đảo hiện tại hết quái

    -- Đảo nhỏ nhất đang tồn tại
    local function lowestIsland()
        for i = 1, 8 do
            if getPivotPosition(getRaidIsland(i)) then return i end
        end
        return nil
    end

    -- Đảo kế tiếp đang tồn tại (> curIsland)
    local function nextIsland(from)
        for i = from + 1, 8 do
            if getPivotPosition(getRaidIsland(i)) then return i end
        end
        return nil
    end

    while alive() do
        -- Trang bị vũ khí
        if tick() - lastEquip >= 0.6 then
            lastEquip = tick()
            pcall(function()
                if type(_G.EquipWeapon) == "function" then
                    _G.EquipWeapon()
                end
            end)
        end

        -- Khởi tạo / đồng bộ đảo hiện tại (vd hồi sinh giữa chừng đang đứng gần đảo 3)
        if curIsland == 0 or not getPivotPosition(getRaidIsland(curIsland)) then
            curIsland = lowestIsland() or 0
        end
        do
            local myRoot = getPlayerRoot()
            if myRoot then
                for i = 8, curIsland + 1, -1 do
                    local cf = getPivotPosition(getRaidIsland(i))
                    if cf and (cf.Position - myRoot.Position).Magnitude <= 450 then
                        curIsland = i
                        break
                    end
                end
            end
        end

        local enemy = curIsland > 0 and getRaidEnemy(curIsland) or getRaidEnemy(nil)
        -- Đảo hiện tại trống > 25s và không có đảo kế -> dọn quái sót ở đảo khác
        if not enemy and clearedSince and tick() - clearedSince > 10 and not nextIsland(curIsland) then
            enemy = getRaidEnemy(nil)
        end

        if enemy and enemy:FindFirstChild("HumanoidRootPart") then
            lastEnemySeen = tick()
            clearedSince = nil
            heldIsland = 0
            targetEnemy = enemy

            local enemyHrp = enemy.HumanoidRootPart
            local currentHrp = getPlayerRoot()

            local auraOn = (_G.RaidKillAura ~= false)
                and curIsland >= (tonumber(_G.RaidKillAuraIsland) or 4)
            if not auraOn and RAID_FIXED.killAuraActive then
                RAID_FIXED.stopAura()
            end

            if auraOn and currentHrp then
                -- KILL AURA (đảo 4-5)
                stopRaidPositionLock()
                if RAID_FIXED.auraIsland == curIsland and RAID_FIXED.auraHoldCF
                    and math.abs((RAID_FIXED.auraHeight or 0) - RAID_FIXED.height()) > 0.5 then
                    RAID_FIXED.stopAura()   -- người dùng đổi độ cao: tính lại điểm giữ
                end
                if RAID_FIXED.auraIsland ~= curIsland or not RAID_FIXED.auraHoldCF then
                    RAID_FIXED.stopAura()
                    RAID_FIXED.auraIsland = curIsland
                    RAID_FIXED.auraGroundY = enemyHrp.Position.Y
                    RAID_FIXED.auraHeight = RAID_FIXED.height()
                    RAID_FIXED.auraHoldCF = CFrame.new(enemyHrp.Position + Vector3.new(0, RAID_FIXED.auraHeight, 0))
                end

                local hold = RAID_FIXED.auraHoldCF
                if (currentHrp.Position - hold.Position).Magnitude > 12 then
                    RAID_FIXED.lastStatus = "Kill Aura: bay tới cụm quái đảo " .. tostring(curIsland)
                    RAID_FIXED.stopAura()  -- hủy aura cũ, đặt lại điểm giữ mới sau khi bay xong
                    RAID_FIXED.auraIsland = curIsland
                    RAID_FIXED.auraGroundY = enemyHrp.Position.Y
                    RAID_FIXED.auraHeight = RAID_FIXED.height()
                    RAID_FIXED.auraHoldCF = CFrame.new(enemyHrp.Position + Vector3.new(0, RAID_FIXED.auraHeight, 0))
                    hold = RAID_FIXED.auraHoldCF
                    if raidFlyTo(hold, flySpeed, alive) then
                        setRaidHold(hold)
                    end
                else
                    if RAID_FIXED.holdCF ~= hold then
                        setRaidHold(hold)
                    end
                    RAID_FIXED.startAura()
                    RAID_FIXED.lastStatus = "Kill Aura đảo " .. tostring(curIsland) .. " - đang gom & diệt quái"
                end
            elseif currentHrp then
                local targetPos = enemyHrp.Position + Vector3.new(0, RAID_FIXED.height(), 0)
                local dist = (currentHrp.Position - targetPos).Magnitude

                if dist > 90 then
                    stopRaidPositionLock()
                    RAID_FIXED.lastStatus = "Bay tới quái Raid (đảo " .. tostring(curIsland) .. ")"
                    raidFlyTo(CFrame.new(targetPos), flySpeed, function()
                        return alive() and enemyAlive(enemy)
                    end)
                else
                    RAID_FIXED.lastStatus = "Đang diệt quái Raid (đảo " .. tostring(curIsland) .. ")"
                    startRaidPositionLock(enemy)
                end
            end
        else
            targetEnemy = nil
            RAID_FIXED.stopAura()
            stopRaidPositionLock()
            clearedSince = clearedSince or tick()

            -- Hết quái đảo hiện tại: chờ 1.5s cho chắc rồi BAY SANG ĐẢO KẾ TIẾP (N+1)
            local nxt = (tick() - clearedSince >= 1.5) and nextIsland(curIsland) or nil

            -- HOÀN THÀNH RAID: đã ở đảo cuối, hết quái 20s và không còn đảo kế -> đánh dấu xong,
            -- reset nhân vật để về phòng chờ (điểm hồi sinh đã đặt ở phòng Raid), rồi vòng lặp
            -- điều khiển tự MUA CHIP -> START -> FARM raid kế tiếp. Tắt reset: _G.RaidResetAfter = false
            if not nxt and tick() - clearedSince > 20
                and curIsland >= (tonumber(RAID_FIXED.finalIsland) or 5) then
                RAID_FIXED.completed = true
                RAID_FIXED.lastStatus = "🏁 Raid completed -> quay về phòng chờ, chuẩn bị raid tiếp"
                raidLog("Raid completed (đảo cuối đã sạch quái)")
                if _G.RaidResetAfter ~= false then
                    pcall(function()
                        local ch = LocalPlayer.Character
                        local hm = ch and ch:FindFirstChildOfClass("Humanoid")
                        if hm then hm.Health = 0 end
                    end)
                end
                break
            end

            if nxt then
                curIsland = nxt
                heldIsland = 0
                clearedSince = nil
                RAID_FIXED.lastStatus = "Chuyển sang đảo Raid " .. tostring(curIsland)
            end

            local cf = curIsland > 0 and getPivotPosition(getRaidIsland(curIsland)) or nil
            if cf then
                local dest = CFrame.new(cf.Position + Vector3.new(0, RAID_FIXED.height(), 0))
                if heldIsland ~= curIsland then
                    RAID_FIXED.currentIsland = curIsland
                    if raidFlyTo(dest, flySpeed, alive) then
                        heldIsland = curIsland
                        setRaidHold(dest)
                    end
                else
                    RAID_FIXED.lastStatus = "Chờ quái đảo Raid " .. tostring(curIsland)
                end
            else
                RAID_FIXED.lastStatus = "Đang chờ đảo Raid xuất hiện"
            end

            task.wait(0.2)
        end

        task.wait(0.05)
    end

    RAID_FIXED.stopAura()
    stopRaidPositionLock()
    setRaidHold(nil)
    targetEnemy = nil

    raidHumanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if raidHumanoid and oldAutoRotate ~= nil then
        raidHumanoid.AutoRotate = oldAutoRotate
    end

    if mySession == RAID_FIXED.session then
        setRaidNoclip(false)
        restoreCharacterCollision()
        RAID_FIXED.currentIsland = 0
        RAID_FIXED.running = false
        RAID_FIXED.lastStatus = isRaidActive() and "Đang chờ Raid kết thúc" or "Raid kết thúc"
    end
    return true
end

-- Auto Buy Chip: chỉ mua khi chưa có chip, đang ở ngoài map Raid và Raid hiện tại đã kết thúc.
_G.MHSpawn(function()
    while task.wait(0.5) do
        pcall(function()
            if raidBuyEnabled() and (World2 or World3) then
                local inRaidMapNow = isInRaidMap()
                if inRaidMapNow then
                    RAID_FIXED.lastStatus = "Đang ở trong map Raid - chưa mua chip lượt kế tiếp"
                elseif not hasSpecialMicrochip() and not isRaidActive()
                    and not RAID_FIXED.starting and not RAID_FIXED.running then
                    local ok, msg = buySelectedRaidChip()
                    if ok then
                        raidLog(msg)
                    elseif msg and msg ~= "Đang chờ cooldown mua chip" and msg ~= "Đang mua chip..." then
                        RAID_FIXED.lastStatus = msg
                    end
                end
            end
        end)
    end
end)

-- BỘ ĐIỀU KHIỂN RAID DUY NHẤT: Auto Start Raid + Auto Farm Raid.
-- (Bản cũ có 2 vòng lặp chồng nhau, vòng Farm huỷ luôn chuyến bay của Auto Start.)
_G.MHSpawn(function()
    while task.wait(0.35) do
        pcall(function()
            local farmOn  = raidFarmEnabled()
            local startOn = raidStartEnabled()

            -- WATCHDOG: cờ "đang Start / đang mua" kẹt quá lâu (remote treo...) -> tự gỡ để Raid không chết im lặng
            if RAID_FIXED.starting and tick() - (RAID_FIXED.startingAt or tick()) > 90 then
                RAID_FIXED.session += 1
                RAID_FIXED.starting = false
                setRaidHold(nil)
                cancelRaidFlight()
                RAID_FIXED.lastStatus = "Start Raid bị kẹt >90s -> đã reset, thử lại"
                raidLog("Watchdog: reset cờ starting")
            end
            if RAID_FIXED.buying and tick() - (RAID_FIXED.buyingAt or tick()) > 90 then
                RAID_FIXED.buying = false
                raidLog("Watchdog: reset cờ buying")
            end

            if (startOn or farmOn) and (World2 or World3) then
                local inRaidMapNow, raidMapDist = isInRaidMap()
                local raidActiveNow = isRaidActive()

                -- Nếu Timer/remote chưa kịp hiện nhưng nhân vật đã ở trên đảo Raid, coi Raid vẫn đang chạy.
                -- Ngoại lệ: completed=true nghĩa là farm đã xác nhận xong; vẫn chặn Start cho đến khi rời map.
                if inRaidMapNow and not RAID_FIXED.completed then
                    raidActiveNow = true
                    RAID_FIXED.activeReason = RAID_FIXED.activeReason or "Vị trí trong map Raid"
                    RAID_FIXED.wasActive = true
                end

                if not raidActiveNow then
                    if inRaidMapNow then
                        RAID_FIXED.lastStatus = "Raid đã farm xong/chờ rời map - chưa kích hoạt lượt mới"
                    else
                        -- Chỉ Start khi Auto Start hoặc Auto Farm Raid đang bật và đang ở ngoài map Raid.
                        if startOn and not RAID_FIXED.starting and not RAID_FIXED.running then
                            if hasSpecialMicrochip() then
                                local ok, msg = clickRaidSummon()
                                if not ok and msg then
                                    RAID_FIXED.lastStatus = msg
                                end
                            elseif not raidBuyEnabled() then
                                RAID_FIXED.lastStatus = "No Special Microchip (bật Auto Buy Chip)"
                            end
                        end
                    end
                elseif farmOn and not RAID_FIXED.running then
                    -- FIX: Raid started nhưng CHỈ farm khi nhân vật đã vào map Raid.
                    -- Chưa vào thì đứng yên chờ server dịch chuyển (không bay / không ghim vị trí).
                    local inMap, dist = inRaidMapNow, raidMapDist
                    local scanned, scanWhy = RAID_FIXED.scan()
                    if (inMap or scanned) and not RAID_FIXED.entered then
                        RAID_FIXED.entered = true
                        RAID_FIXED.lastStatus = "✅ Đã xác nhận đang ở trong Raid (" .. tostring(scanWhy) .. ") -> bắt đầu farm"
                        raidLog("Quét: đã ở trong Raid -", scanWhy)
                    end
                    RAID_FIXED.scanInfo = scanWhy
                    RAID_FIXED.activeSince = RAID_FIXED.activeSince or tick()
                    if not RAID_FIXED.entered and tick() - RAID_FIXED.activeSince > 3 and getRaidEnemy(nil) then
                        RAID_FIXED.entered = true  -- FIX: dự phòng khi toạ độ đảo lệch / chưa đọc được vị trí
                        raidLog("Raid đang chạy và có quái -> vào farm (dự phòng)")
                    end

                    if RAID_FIXED.entered then
                        _G.MHSpawn(function()
                            local ok, err = pcall(farmRaidIslands)
                            if not ok then
                                RAID_FIXED.running = false
                                RAID_FIXED.lastStatus = "Raid lỗi: " .. tostring(err)
                                raidLog("farmRaidIslands error:", err)
                            end
                        end)
                    else
                        -- Nhả điều khiển để server dịch chuyển nhân vật vào map Raid được
                        if (RAID_FIXED.holdCF or RAID_FIXED.flying) and not RAID_FIXED.fallbackBusy then
                            cancelRaidFlight()
                            setRaidHold(nil)
                        end
                        RAID_FIXED.lastStatus = ((dist == math.huge)
                            and "Chờ vào map Raid (chưa thấy đảo Raid)..."
                            or string.format("Chờ vào map Raid... (cách đảo gần nhất %d studs)", math.floor(dist)))
                            .. " | quét: " .. tostring(scanWhy)

                        -- FIX: sau 15s mà vẫn chưa vào map Raid (server không tự dịch chuyển / bị kéo về phòng chờ)
                        -- -> tự bay tới đảo Raid thấp nhất đang tồn tại, tới nơi rồi mới farm.
                        if tick() - RAID_FIXED.activeSince > 15 and not RAID_FIXED.fallbackBusy
                            and tick() - (RAID_FIXED.fallbackAt or 0) > 10 then
                            local locations = getRaidLocations()
                            local destCF
                            if locations then
                                for i = 1, 8 do
                                    if not RAID_FIXED.baseIslands[i] then
                                        local isl = locations:FindFirstChild("Island " .. i) or locations:FindFirstChild("Island " .. i, true)
                                        local cf = getPivotPosition(isl)
                                        if cf then
                                            destCF = cf
                                            break
                                        end
                                    end
                                end
                            end
                            if destCF then
                                RAID_FIXED.fallbackBusy = true
                                RAID_FIXED.fallbackAt = tick()
                                RAID_FIXED.lastStatus = "Chưa vào map Raid -> tự bay tới đảo Raid..."
                                _G.MHSpawn(function()
                                    pcall(function()
                                        local dest = CFrame.new(destCF.Position + Vector3.new(0, RAID_FIXED.height(), 0))
                                        pcall(function() LocalPlayer:RequestStreamAroundAsync(dest.Position) end)
                                        raidFlyTo(dest, flySpeed, function()
                                            return raidFarmEnabled() and isRaidActive()
                                        end)
                                    end)
                                    RAID_FIXED.fallbackBusy = false
                                end)
                            end
                        end
                    end
                end
            elseif not startOn then
                if RAID_FIXED.running or RAID_FIXED.starting or RAID_FIXED.holdCF or RAID_FIXED.noclipEnabled or RAID_FIXED.flying then
                    RAID_FIXED.session += 1 -- huỷ mọi tiến trình Raid đang chạy
                    RAID_FIXED.running = false
                    RAID_FIXED.starting = false
                    RAID_FIXED.stopAura()
                    stopRaidPositionLock()
                    setRaidHold(nil)
                    cancelRaidFlight()
                    setRaidNoclip(false)
                    restoreCharacterCollision()
                end
            end
        end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.2)
    RAID_FIXED.session += 1 -- huỷ tiến trình Raid của nhân vật cũ
    RAID_FIXED.stopAura()
    stopRaidPositionLock()
    setRaidHold(nil)
    cancelRaidFlight()
    setRaidNoclip(false)
    RAID_FIXED.running = false
    RAID_FIXED.entered = false
    RAID_FIXED.activeSince = nil
    RAID_FIXED.currentIsland = 0
end)
end

-- Nút trạng thái nhỏ trong tab Raid.
do
    local raidStatus = Instance.new("TextLabel")
    raidStatus.Name = "RaidStatus"
    raidStatus.Size = UDim2.new(1, -24, 0, 22)
    raidStatus.Position = UDim2.new(0, 12, 0, 176)
    raidStatus.BackgroundTransparency = 1
    raidStatus.Text = "⚡ " .. RAID_FIXED.lastStatus
    raidStatus.TextColor3 = Color3.fromRGB(190, 190, 200)
    raidStatus.TextSize = 10
    raidStatus.Font = Enum.Font.Gotham
    raidStatus.TextXAlignment = Enum.TextXAlignment.Left
    raidStatus.Parent = raidFrame

    _G.MHSpawn(function()
        while raidStatus.Parent do
            raidStatus.Text = "⚡ " .. tostring(RAID_FIXED.lastStatus)
            task.wait(0.5)
        end
    end)
end

-- AUTO FARM CHEST (tab Farm)
createToggleFeature(farmPage, "AutoFarmChestToggle", "Auto Farm Chest", "Collect chests when higher-priority tasks are idle; resume after farming/Raid finishes", 31, autoChestEnabled, function(state)
    autoChestEnabled = state
    -- Không tự tắt/tắt hộ các farm khác. Bộ điều phối sẽ nhường quyền di chuyển.
    -- Khi tắt, điều kiện keepGoing của chuyến bay rương sẽ tự hủy chuyến đó.
end)

-- TAB GACHA CONTENT
createToggleFeature(gachaPage, "AutoRandomBonesToggle", "Auto Random Bones", "Automatically spend 50 Bones for a random reward from Death King", 1, autoRandomBonesEnabled, function(state)
    autoRandomBonesEnabled = state
end)

createToggleFeature(gachaPage, "AutoStoreFruitToggle", "Auto Store Fruit", "Automatically store all Devil Fruits from the Backpack in storage", 3, autoStoreFruitEnabled, function(state)
    autoStoreFruitEnabled = state
end)

createToggleFeature(gachaPage, "AutoPickupFruitToggle", "Auto Collect Fruit", "Prioritize fruit collection after Raid; pause regular farming and then resume", 5, _G.AutoPickupFruit, function(state)
    _G.AutoPickupFruit = state
    if not state then
        -- Chỉ dừng chuyến bay của tính năng này khi nó còn quyền điều khiển;
        -- không hủy nhầm tween của Raid / Mua võ đang có ưu tiên cao hơn.
        local ownsControl = Q.SmartController.canRun("fruit")
        _G.FruitPickupBusy = false
        if ownsControl then stopAllFlying() end
    end
end)

createToggleFeature(gachaPage, "AutoRandomFruitToggle", "Auto Buy Random Fruit", "Try purchasing remotely; if rejected, fly to Zioles and buy. Limited to once every 2 hours; Lv. 50+ required. Use with Auto Store Fruit", 4, autoRandomFruitEnabled, function(state)
    autoRandomFruitEnabled = state
    if not state then _G.FruitPickupBusy = false end
end)

-- Thẻ trạng thái Random/Store trên tab Gacha (IIFE để không tăng số local của chunk chính)
;(function()
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 62)
    card.BackgroundColor3 = BANANA_CARD
    card.LayoutOrder = 10
    card.Parent = gachaPage
    addCorner(card, 8)
    addStroke(card, BANANA_CARD_BORDER, 1)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -24, 1, -8)
    txt.Position = UDim2.new(0, 12, 0, 4)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.fromRGB(190, 190, 200)
    txt.TextSize = 11
    txt.Font = Enum.Font.Gotham
    txt.TextWrapped = true
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextYAlignment = Enum.TextYAlignment.Top
    txt.Parent = card

    _G.MHSpawn(function()
        while txt.Parent do
            txt.Text = "🎲 Random: " .. tostring(_G.RandomFruitStatus or "-")
                .. "\n📦 Store: " .. tostring(_G.StoreFruitStatus or "-")
            task.wait(0.5)
        end
    end)
end)()

-- KHUNG HIỂN THỊ DANH SÁCH TRÁI ÁC QUỶ ĐANG BÁN TRONG SHOP
local stockFrame = Instance.new("Frame")
stockFrame.Size = UDim2.new(1, 0, 0, 230)
stockFrame.BackgroundColor3 = BANANA_CARD
stockFrame.LayoutOrder = 1
stockFrame.Parent = shopPage
addCorner(stockFrame, 8)
addStroke(stockFrame, BANANA_CARD_BORDER, 1.2)

local stockTitle = Instance.new("TextLabel")
stockTitle.Size = UDim2.new(1, -200, 0, 30)
stockTitle.Position = UDim2.new(0, 12, 0, 4)
stockTitle.BackgroundTransparency = 1
stockTitle.Text = "🍎 Stock: Regular Shop"
stockTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
stockTitle.TextSize = 12
stockTitle.Font = Enum.Font.GothamBold
stockTitle.TextXAlignment = Enum.TextXAlignment.Left
stockTitle.Parent = stockFrame


local btnNormalStock = Instance.new("TextButton")
btnNormalStock.Size = UDim2.new(0, 85, 0, 24)
btnNormalStock.Position = UDim2.new(1, -180, 0, 6)
btnNormalStock.BackgroundColor3 = BANANA_YELLOW
btnNormalStock.Text = "🍎 Regular Shop"
btnNormalStock.TextColor3 = BANANA_TEXT_ON
btnNormalStock.Font = Enum.Font.GothamBold
btnNormalStock.TextSize = 10
btnNormalStock.Parent = stockFrame
addCorner(btnNormalStock, 6)

local btnMirageStock = Instance.new("TextButton")
btnMirageStock.Size = UDim2.new(0, 90, 0, 24)
btnMirageStock.Position = UDim2.new(1, -90, 0, 6)
btnMirageStock.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
btnMirageStock.Text = "🏝 Mirage Island"
btnMirageStock.TextColor3 = Color3.fromRGB(200, 200, 200)
btnMirageStock.Font = Enum.Font.GothamBold
btnMirageStock.TextSize = 10
btnMirageStock.Parent = stockFrame
addCorner(btnMirageStock, 6)

local stockScroll = Instance.new("ScrollingFrame")
stockScroll.Size = UDim2.new(1, -20, 0, 180)
stockScroll.Position = UDim2.new(0, 10, 0, 38)
stockScroll.BackgroundTransparency = 1
stockScroll.BorderSizePixel = 0
stockScroll.ScrollBarThickness = 3
stockScroll.ScrollBarImageColor3 = BANANA_YELLOW
stockScroll.Parent = stockFrame

local stockListLayout = Instance.new("UIListLayout")
stockListLayout.Parent = stockScroll
stockListLayout.SortOrder = Enum.SortOrder.LayoutOrder
stockListLayout.Padding = UDim.new(0, 4)

local function updateFruitStock(isMirage)
    currentShopMode = isMirage
    if isMirage then
        stockTitle.Text = "🏝️ Stock: Mirage Island"
        btnMirageStock.BackgroundColor3 = BANANA_YELLOW
        btnMirageStock.TextColor3 = BANANA_TEXT_ON
        btnNormalStock.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        btnNormalStock.TextColor3 = Color3.fromRGB(200, 200, 200)
    else
        stockTitle.Text = "🍎 Stock: Regular Shop"
        btnNormalStock.BackgroundColor3 = BANANA_YELLOW
        btnNormalStock.TextColor3 = BANANA_TEXT_ON
        btnMirageStock.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        btnMirageStock.TextColor3 = Color3.fromRGB(200, 200, 200)
    end

    for _, child in pairs(stockScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then 
            child:Destroy() 
        end
    end

    pcall(function()
        local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
        if not commF then return end

        local fruitsData = isMirage and commF:InvokeServer("GetFruits", true) or commF:InvokeServer("GetFruits")
        if type(fruitsData) == "table" then
            local count = 0
            for _, fruit in pairs(fruitsData) do
                if fruit.OnSale then
                    count = count + 1
                    local itemFrame = Instance.new("Frame")
                    itemFrame.Size = UDim2.new(1, -6, 0, 28)
                    itemFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                    itemFrame.LayoutOrder = count
                    itemFrame.Parent = stockScroll
                    addCorner(itemFrame, 5)

                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
                    nameLabel.Position = UDim2.new(0, 8, 0, 0)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Text = "• " .. tostring(fruit.Name or "Unknown")
                    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLabel.Font = Enum.Font.GothamBold
                    nameLabel.TextSize = 11
                    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                    nameLabel.Parent = itemFrame

                    local priceLabel = Instance.new("TextLabel")
                    priceLabel.Size = UDim2.new(0.4, -8, 1, 0)
                    priceLabel.Position = UDim2.new(0.6, 0, 0, 0)
                    priceLabel.BackgroundTransparency = 1
                    
                    local priceText = fruit.Price and ("$" .. string.format("%d", fruit.Price)) or "N/A"
                    priceLabel.Text = priceText
                    priceLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
                    priceLabel.Font = Enum.Font.GothamBold
                    priceLabel.TextSize = 11
                    priceLabel.TextXAlignment = Enum.TextXAlignment.Right
                    priceLabel.Parent = itemFrame
                end
            end
            
            if count == 0 then
                local emptyLabel = Instance.new("TextLabel")
                emptyLabel.Size = UDim2.new(1, 0, 0, 30)
                emptyLabel.BackgroundTransparency = 1
                emptyLabel.Text = isMirage and "Mirage Island stock data not found!" or "Unable to load shop data!"
                emptyLabel.TextColor3 = Color3.fromRGB(200, 150, 150)
                emptyLabel.Font = Enum.Font.Gotham
                emptyLabel.TextSize = 11
                emptyLabel.Parent = stockScroll
            end

            stockScroll.CanvasSize = UDim2.new(0, 0, 0, count * 32)
        end
    end)
end

btnNormalStock.MouseButton1Click:Connect(function()
    updateFruitStock(false)
end)

btnMirageStock.MouseButton1Click:Connect(function()
    updateFruitStock(true)
end)

_G.MHSpawn(function()
    task.wait(1)
    updateFruitStock(false)
end)

-- TAB SETTINGS & CONFIG
local weaponDropdownCard = Instance.new("Frame")
weaponDropdownCard.Size = UDim2.new(1, 0, 0, 44)
weaponDropdownCard.BackgroundColor3 = BANANA_CARD
weaponDropdownCard.LayoutOrder = 1
weaponDropdownCard.ClipsDescendants = true
weaponDropdownCard.Parent = settingsPage
addCorner(weaponDropdownCard, 8)
addStroke(weaponDropdownCard, BANANA_CARD_BORDER, 1.2)

local weaponDropdownBtn = Instance.new("TextButton")
weaponDropdownBtn.Size = UDim2.new(1, 0, 0, 44)
weaponDropdownBtn.BackgroundTransparency = 1
weaponDropdownBtn.Text = ""
weaponDropdownBtn.Parent = weaponDropdownCard

local weaponDropdownLabel = Instance.new("TextLabel")
weaponDropdownLabel.Size = UDim2.new(1, -45, 1, 0)
weaponDropdownLabel.Position = UDim2.new(0, 12, 0, 0)
weaponDropdownLabel.BackgroundTransparency = 1
weaponDropdownLabel.Text = "Weapon: " .. selectedWeapon
weaponDropdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
weaponDropdownLabel.TextSize = 12
weaponDropdownLabel.Font = Enum.Font.GothamBold
weaponDropdownLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponDropdownLabel.Parent = weaponDropdownBtn

local weaponArrow = Instance.new("TextLabel")
weaponArrow.Size = UDim2.new(0, 35, 1, 0)
weaponArrow.Position = UDim2.new(1, -35, 0, 0)
weaponArrow.BackgroundTransparency = 1
weaponArrow.Text = "▼"
weaponArrow.TextColor3 = BANANA_YELLOW
weaponArrow.TextSize = 12
weaponArrow.Font = Enum.Font.GothamBold
weaponArrow.Parent = weaponDropdownBtn

local weaponOptionsList = Instance.new("Frame")
weaponOptionsList.Size = UDim2.new(1, -20, 0, 142)
weaponOptionsList.Position = UDim2.new(0, 10, 0, 44)
weaponOptionsList.BackgroundTransparency = 1
weaponOptionsList.Parent = weaponDropdownCard

local weaponListLayout = Instance.new("UIListLayout")
weaponListLayout.Parent = weaponOptionsList
weaponListLayout.SortOrder = Enum.SortOrder.LayoutOrder
weaponListLayout.Padding = UDim.new(0, 6)

local isWeaponDropdownOpen = false
weaponDropdownBtn.MouseButton1Click:Connect(function()
    isWeaponDropdownOpen = not isWeaponDropdownOpen
    weaponArrow.Text = isWeaponDropdownOpen and "▲" or "▼"
    weaponDropdownCard.Size = isWeaponDropdownOpen and UDim2.new(1, 0, 0, 195) or UDim2.new(1, 0, 0, 44)
end)

for index, wName in ipairs(weaponTypes) do
    local wOptBtn = Instance.new("TextButton")
    wOptBtn.Size = UDim2.new(1, 0, 0, 30)
    wOptBtn.Text = "   " .. wName
    wOptBtn.TextXAlignment = Enum.TextXAlignment.Left
    wOptBtn.Font = Enum.Font.GothamBold
    wOptBtn.TextSize = 12
    wOptBtn.LayoutOrder = index
    wOptBtn.Parent = weaponOptionsList
    addCorner(wOptBtn, 6)

    if wName == selectedWeapon then
        wOptBtn.BackgroundColor3 = BANANA_YELLOW
        wOptBtn.TextColor3 = BANANA_TEXT_ON
    else
        wOptBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        wOptBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
    end

    wOptBtn.MouseButton1Click:Connect(function()
        selectedWeapon = wName
        _G.SelectWeapon = wName
        weaponDropdownLabel.Text = "Weapon: " .. selectedWeapon
        isWeaponDropdownOpen = false
        weaponArrow.Text = "▼"
        weaponDropdownCard.Size = UDim2.new(1, 0, 0, 44)

        for _, child in pairs(weaponOptionsList:GetChildren()) do
            if child:IsA("TextButton") then
                if string.gsub(child.Text, "^%s+", "") == selectedWeapon then
                    child.BackgroundColor3 = BANANA_YELLOW
                    child.TextColor3 = BANANA_TEXT_ON
                else
                    child.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                    child.TextColor3 = Color3.fromRGB(150, 150, 160)
                end
            end
        end
    end)
end

-- HEIGHT SLIDER
local heightSliderCard = Instance.new("Frame")
heightSliderCard.Size = UDim2.new(1, 0, 0, 56)
heightSliderCard.BackgroundColor3 = BANANA_CARD
heightSliderCard.LayoutOrder = 2
heightSliderCard.Parent = settingsPage
addCorner(heightSliderCard, 8)
addStroke(heightSliderCard, BANANA_CARD_BORDER, 1.2)

local sliderTitle = Instance.new("TextLabel")
sliderTitle.Size = UDim2.new(0.65, 0, 0, 28)
sliderTitle.Position = UDim2.new(0, 12, 0, 4)
sliderTitle.BackgroundTransparency = 1
sliderTitle.Text = "Farm Height (Flight Altitude)"
sliderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
sliderTitle.TextSize = 12
sliderTitle.Font = Enum.Font.GothamBold
sliderTitle.TextXAlignment = Enum.TextXAlignment.Left
sliderTitle.Parent = heightSliderCard

local valueBox = Instance.new("TextBox")
valueBox.Size = UDim2.new(0, 60, 0, 24)
valueBox.Position = UDim2.new(1, -70, 0, 6)
valueBox.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
valueBox.TextColor3 = Color3.fromRGB(255, 255, 255)
valueBox.TextSize = 12
valueBox.Font = Enum.Font.GothamBold
valueBox.Text = tostring(farmDistanceHeight)
valueBox.ClearTextOnFocus = false
valueBox.Parent = heightSliderCard
addCorner(valueBox, 6)

local sliderTrack = Instance.new("TextButton")
sliderTrack.Size = UDim2.new(1, -24, 0, 8)
sliderTrack.Position = UDim2.new(0, 12, 1, -14)
sliderTrack.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
sliderTrack.BorderSizePixel = 0
sliderTrack.Text = ""
sliderTrack.AutoButtonColor = false
sliderTrack.Parent = heightSliderCard
addCorner(sliderTrack, 4)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(math.clamp(tonumber(farmDistanceHeight) or 35, 0, 100) / 100, 0, 1, 0)
sliderFill.BackgroundColor3 = BANANA_YELLOW
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
addCorner(sliderFill, 4)

local isDraggingSlider = false
local function updateSliderValue(inputX)
    local trackAbsPos = sliderTrack.AbsolutePosition.X
    local trackAbsSize = sliderTrack.AbsoluteSize.X
    if trackAbsSize <= 0 then return end
    local relativeX = math.clamp((inputX - trackAbsPos) / trackAbsSize, 0, 1)
    local val = math.floor(relativeX * 100)
    farmDistanceHeight = val
    valueBox.Text = tostring(val)
    sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
end

sliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = true
        updateSliderValue(input.Position.X)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSliderValue(input.Position.X)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = false
    end
end)

valueBox.FocusLost:Connect(function()
    local num = tonumber(valueBox.Text)
    if num then
        num = math.clamp(math.floor(num), 0, 100)
        farmDistanceHeight = num
        valueBox.Text = tostring(num)
        sliderFill.Size = UDim2.new(num / 100, 0, 1, 0)
    else
        valueBox.Text = tostring(farmDistanceHeight)
    end
end)

createToggleFeature(settingsPage, nil, "Bring Mob", "Gather nearby mobs into one location", 16, bringMobsEnabled, function(state) 
    bringMobsEnabled = state 
end)

local function createInputFeature(parentPage, title, defaultVal, layoutOrder, callback)
    local inputCard = Instance.new("Frame")
    inputCard.Size = UDim2.new(1, 0, 0, 38)
    inputCard.BackgroundColor3 = BANANA_CARD
    inputCard.LayoutOrder = layoutOrder
    inputCard.Parent = parentPage
    addCorner(inputCard, 6)

    local inputTitle = Instance.new("TextLabel")
    inputTitle.Size = UDim2.new(0.55, 0, 1, 0)
    inputTitle.Position = UDim2.new(0, 12, 0, 0)
    inputTitle.BackgroundTransparency = 1
    inputTitle.Text = title
    inputTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    inputTitle.TextSize = 12
    inputTitle.Font = Enum.Font.GothamMedium
    inputTitle.TextXAlignment = Enum.TextXAlignment.Left
    inputTitle.Parent = inputCard

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(0, 110, 0, 26)
    textBox.Position = UDim2.new(1, -120, 0.5, -13)
    textBox.BackgroundColor3 = BANANA_SIDEBAR
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.TextSize = 12
    textBox.Font = Enum.Font.GothamMedium
    textBox.Text = tostring(defaultVal)
    textBox.ClearTextOnFocus = false
    textBox.Parent = inputCard
    addCorner(textBox, 6)
    local boxStroke = addStroke(textBox, BANANA_CARD_BORDER, 1)
    textBox.Focused:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.12), {Color = BANANA_YELLOW}):Play()
    end)

    textBox.FocusLost:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.12), {Color = BANANA_CARD_BORDER}):Play()
        local val = tonumber(textBox.Text)
        if val then
            callback(val)
        else
            textBox.Text = tostring(defaultVal)
            callback(defaultVal)
        end
    end)
end

createInputFeature(settingsPage, "Bring Mob Count", maxBringCount, 17, function(val)
    maxBringCount = val
end)

-- =========================================================
-- TEAM SELECT: chọn phe Hải tặc / Hải quân + tự động chọn phe
-- Dùng CommF_ / SetTeam và kiểm tra lại LocalPlayer.Team trước khi báo thành công.
-- Đóng gói trong hàm riêng để tránh tăng số local của script chính.
-- =========================================================
;(function()
    local teamState = {
        selected = (_G.MinhHubSelectedTeam == "Marines") and "Marines" or "Pirates",
        enabled = (_G.MinhHubAutoSelectTeam ~= false),
        lastAttempt = 0,
        attempts = 0,
        message = "Chọn phe mong muốn rồi bật Auto Select Team",
        statusLabel = nil,
        buttons = {},
    }

    local teamLabels = {
        Pirates = "🏴‍☠️ Pirates",
        Marines = "⚓ Marines",
    }

    local function persistTeam()
        local st = _G.MinhHubSettings
        if st then
            st.data.team = teamState.selected
            st.data.autoTeam = teamState.enabled
            st.save()
        end
    end

    local function displayTeam(teamName)
        if teamName == "Pirates" then return "Pirates" end
        if teamName == "Marines" then return "Marines" end
        return "No team selected"
    end

    local function getCurrentTeamName()
        local team = LocalPlayer and LocalPlayer.Team
        return team and team.Name or nil
    end

    local function refreshTeamButtons()
        for teamName, button in pairs(teamState.buttons) do
            local selected = teamName == teamState.selected
            button.BackgroundColor3 = selected and BANANA_YELLOW or BANANA_SIDEBAR
            button.TextColor3 = selected and BANANA_TEXT_ON or Color3.fromRGB(190, 194, 205)
            button.Text = (selected and "✓ " or "  ") .. teamLabels[teamName]
        end
    end

    local function refreshTeamStatus()
        if not teamState.statusLabel or not teamState.statusLabel.Parent then return end
        local current = getCurrentTeamName()
        teamState.statusLabel.Text = "Current: " .. displayTeam(current)
            .. "  |  Target: " .. displayTeam(teamState.selected)
            .. "\nStatus: " .. tostring(teamState.message)
            .. "  •  Auto: " .. (teamState.enabled and "BẬT" or "TẮT")
    end

    local teamCard = Instance.new("Frame")
    teamCard.Name = "TeamSelectorCard"
    teamCard.Size = UDim2.new(1, 0, 0, 106)
    teamCard.BackgroundColor3 = BANANA_CARD
    teamCard.BackgroundTransparency = 0.2
    teamCard.LayoutOrder = 4
    teamCard.Parent = settingsPage
    addCorner(teamCard, 8)
    addStroke(teamCard, BANANA_CARD_BORDER, 1.2)

    local teamTitle = Instance.new("TextLabel")
    teamTitle.Name = "TeamSelectorTitle"
    teamTitle.Size = UDim2.new(1, -20, 0, 22)
    teamTitle.Position = UDim2.new(0, 12, 0, 4)
    teamTitle.BackgroundTransparency = 1
    teamTitle.Text = "Select Team"
    teamTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    teamTitle.TextSize = 12
    teamTitle.Font = Enum.Font.GothamBold
    teamTitle.TextXAlignment = Enum.TextXAlignment.Left
    teamTitle.Parent = teamCard

    local function makeTeamButton(teamName, xPosition)
        local button = Instance.new("TextButton")
        button.Name = teamName .. "TeamButton"
        button.Size = UDim2.new(0.5, -18, 0, 28)
        button.Position = xPosition
        button.BackgroundColor3 = BANANA_SIDEBAR
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Text = teamLabels[teamName]
        button.TextColor3 = Color3.fromRGB(190, 194, 205)
        button.TextSize = 11
        button.Font = Enum.Font.GothamBold
        button.Parent = teamCard
        addCorner(button, 6)
        addStroke(button, BANANA_CARD_BORDER, 1)
        teamState.buttons[teamName] = button

        button.MouseButton1Click:Connect(function()
            teamState.selected = teamName
            _G.MinhHubSelectedTeam = teamName
            teamState.lastAttempt = 0
            teamState.attempts = 0
            teamState.message = "Selected target: " .. displayTeam(teamName)
            persistTeam()
            refreshTeamButtons()
            refreshTeamStatus()
        end)
        return button
    end

    makeTeamButton("Pirates", UDim2.new(0, 10, 0, 29))
    makeTeamButton("Marines", UDim2.new(0.5, 8, 0, 29))

    local teamStatus = Instance.new("TextLabel")
    teamStatus.Name = "TeamSelectorStatus"
    teamStatus.Size = UDim2.new(1, -20, 0, 39)
    teamStatus.Position = UDim2.new(0, 10, 0, 62)
    teamStatus.BackgroundTransparency = 1
    teamStatus.Text = "Reading team information..."
    teamStatus.TextColor3 = Color3.fromRGB(180, 185, 198)
    teamStatus.TextSize = 10
    teamStatus.Font = Enum.Font.Gotham
    teamStatus.TextWrapped = true
    teamStatus.TextXAlignment = Enum.TextXAlignment.Left
    teamStatus.TextYAlignment = Enum.TextYAlignment.Top
    teamStatus.Parent = teamCard
    teamState.statusLabel = teamStatus

    refreshTeamButtons()
    refreshTeamStatus()

    createToggleFeature(settingsPage, "AutoSelectTeamToggle", "Auto Select Team",
        "Automatically select the team marked above (Pirates or Marines)", 3, teamState.enabled, function(state)
            teamState.enabled = state
            _G.MinhHubAutoSelectTeam = state
            teamState.lastAttempt = 0
            teamState.attempts = 0
            if state then
                teamState.message = "Automatically selecting " .. displayTeam(teamState.selected)
            else
                teamState.message = "Auto Select Team disabled"
            end
            persistTeam()
            refreshTeamStatus()
        end)

    -- Tách vòng thử chọn phe khỏi giao diện để không làm treo menu.
    _G.MHSpawn(function()
        while task.wait(0.75) do
            pcall(function()
                refreshTeamStatus()
                if not teamState.enabled then return end

                local currentTeam = getCurrentTeamName()
                if currentTeam == teamState.selected then
                    teamState.message = "Đã ở đúng phe"
                    teamState.lastAttempt = tick()
                    teamState.attempts = 0
                    refreshTeamStatus()
                    return
                end

                -- Hết 5 lần thì nghỉ 30 giây rồi thử lại (không bỏ cuộc vĩnh viễn)
                if teamState.attempts >= 5 then
                    if tick() - teamState.lastAttempt < 30 then
                        teamState.message = "Chưa đổi được phe; sẽ thử lại sau ít giây"
                        refreshTeamStatus()
                        return
                    end
                    teamState.attempts = 0
                end
                if tick() - teamState.lastAttempt < 4 then return end

                -- Chờ game + remote sẵn sàng (server mới load chậm) trước khi tính lượt thử
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local commF = remotes and remotes:FindFirstChild("CommF_")
                if not game:IsLoaded() or not commF or not commF:IsA("RemoteFunction") then
                    teamState.message = "Đang chờ game/Remote chọn phe sẵn sàng..."
                    refreshTeamStatus()
                    return
                end

                teamState.lastAttempt = tick()
                teamState.attempts = teamState.attempts + 1
                teamState.message = "Đang gửi yêu cầu chọn phe (" .. tostring(teamState.attempts) .. "/5)..."
                refreshTeamStatus()

                local ok, err = pcall(function()
                    return commF:InvokeServer("SetTeam", teamState.selected)
                end)
                task.wait(0.25)
                if getCurrentTeamName() == teamState.selected then
                    teamState.message = "Đã chọn thành công " .. displayTeam(teamState.selected)
                elseif ok then
                    teamState.message = "The server has not switched teams; retrying"
                else
                    teamState.message = "Request failed; retrying"
                    warn("[Minh Hub] Auto Select Team error: " .. tostring(err))
                end
                refreshTeamStatus()
            end)
        end
    end)
end)()


createToggleFeature(settingsPage, nil, "Fast Attack", "Very fast, no-delay attacks for Melee, Sword, and Blox Fruit", 11, fastAttackEnabled, function(state) fastAttackEnabled = state end)

-- ==================== DODGE CONFIG GLOBAL ====================
createToggleFeature(settingsPage, nil, "Auto Buso Haki", "Automatically activate Armament Haki", 21, autoHakiEnabled, function(state)
    autoHakiEnabled = state
end)
createToggleFeature(settingsPage, nil, "Auto Observation Haki", "Automatically activate Observation Haki / Instinct (E key)", 22, autoObservationEnabled, function(state)
    autoObservationEnabled = state
    if state then
        observationState.lastTry = 0
        _G.MHSpawn(function()
            task.wait(0.15)
            if ensureObservation then pcall(ensureObservation) end
        end)
    end
end)
-- =========================================================
-- XÓA SƯƠNG MÙ: chỉnh Lighting Fog và Atmosphere ở phía client
-- Bật: giảm sương mù để nhìn xa rõ hơn.
-- Tắt: khôi phục giá trị ban đầu được lưu trước khi bật.
-- =========================================================
do
    local Lighting = game:GetService("Lighting")
    local fogEnabled = false
    local originalFogStart, originalFogEnd
    local atmosphereOriginals = {}
    local atmosphereAddedConnection

    local function applyNoFogToAtmosphere(obj)
        if not obj or not obj:IsA("Atmosphere") then return end
        if not atmosphereOriginals[obj] then
            atmosphereOriginals[obj] = {
                Density = obj.Density,
                Haze = obj.Haze,
                Glare = obj.Glare,
            }
        end
        pcall(function()
            obj.Density = 0
            obj.Haze = 0
            obj.Glare = 0
        end)
    end

    local function setNoFog(enabled)
        if enabled == fogEnabled then return end
        fogEnabled = enabled

        if enabled then
            originalFogStart = Lighting.FogStart
            originalFogEnd = Lighting.FogEnd
            table.clear(atmosphereOriginals)

            pcall(function()
                Lighting.FogStart = 0
                Lighting.FogEnd = 1000000
            end)
            for _, obj in ipairs(Lighting:GetDescendants()) do
                if obj:IsA("Atmosphere") then
                    applyNoFogToAtmosphere(obj)
                end
            end
            if atmosphereAddedConnection then
                atmosphereAddedConnection:Disconnect()
                atmosphereAddedConnection = nil
            end
            atmosphereAddedConnection = Lighting.DescendantAdded:Connect(function(obj)
                if fogEnabled then applyNoFogToAtmosphere(obj) end
            end)
        else
            if atmosphereAddedConnection then
                atmosphereAddedConnection:Disconnect()
                atmosphereAddedConnection = nil
            end
            pcall(function()
                if originalFogStart ~= nil then Lighting.FogStart = originalFogStart end
                if originalFogEnd ~= nil then Lighting.FogEnd = originalFogEnd end
            end)
            for atmosphere, values in pairs(atmosphereOriginals) do
                if atmosphere and atmosphere.Parent then
                    pcall(function()
                        atmosphere.Density = values.Density
                        atmosphere.Haze = values.Haze
                        atmosphere.Glare = values.Glare
                    end)
                end
            end
            table.clear(atmosphereOriginals)
        end
    end

    createToggleFeature(settingsPage, nil, "Remove Fog", "Reduce Fog/Atmosphere for clearer long-distance vision", 34, false, function(state)
        setNoFog(state)
    end)
end


-- WALK ON WATER: phóng to mặt nước (WaterBase-Plane) để đứng/đi trên nước
_G.WalkonWater = true

-- Chỉ áp dụng 1 lần (khi load script, và 1 lần mỗi khi bấm bật/tắt), không lặp liên tục
function Q.applyWalkOnWater()
    pcall(function()
        local map = workspace:FindFirstChild("Map") or workspace:WaitForChild("Map", 15)
        local water = map and (map:FindFirstChild("WaterBase-Plane") or map:WaitForChild("WaterBase-Plane", 15))
        if water then
            if _G.WalkonWater then
                water.Size = Vector3.new(1000, 112, 1000)
            else
                water.Size = Vector3.new(1000, 80, 1000)
            end
        end
    end)
end

createToggleFeature(settingsPage, "WalkOnWaterToggle", "Walk On Water", "Stand and walk on water", 31, _G.WalkonWater, function(state)
    _G.WalkonWater = state
    _G.MHSpawn(Q.applyWalkOnWater)
end)

_G.MHSpawn(Q.applyWalkOnWater)

-- XUYÊN TƯỜNG (NOCLIP): mặc định BẬT, lưu vào MinhHub_Settings.json
Q.NOCLIP = { on = true, orig = setmetatable({}, {__mode = "k"}), parts = {}, char = nil, at = 0 }
do
    local nc = Q.NOCLIP
    local st0 = _G.MinhHubSettings
    if st0 and st0.data.noclip ~= nil then nc.on = (st0.data.noclip == true) end

    function nc.restore()
        for part in pairs(nc.orig) do
            if part.Parent then pcall(function() part.CanCollide = true end) end
        end
        table.clear(nc.orig)
    end

    RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        if not nc.on then
            if next(nc.orig) then nc.restore() end
            return
        end
        if nc.char ~= char or tick() - nc.at > 0.5 then
            nc.char, nc.at, nc.parts = char, tick(), {}
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then nc.parts[#nc.parts + 1] = p end
            end
        end
        for _, p in ipairs(nc.parts) do
            if p.Parent and p.CanCollide then
                nc.orig[p] = true
                p.CanCollide = false
            end
        end
    end)

    createToggleFeature(settingsPage, "NoclipToggle", "Noclip",
        "Move through walls and obstacles (the character can still stand on the ground)", 35, nc.on, function(state)
            nc.on = state
            local st = _G.MinhHubSettings
            if st then st.data.noclip = state; st.save() end
            if not state then nc.restore() end
        end)
end
createToggleFeature(settingsPage, nil, "Auto Race V3", "Automatically use the Race V3 skill (T key)", 23, autoRaceV3Enabled, function(state) autoRaceV3Enabled = state end)
createToggleFeature(settingsPage, nil, "Auto Race V4", "Automatically activate Race V4 awakening (Y key)", 24, autoRaceV4Enabled, function(state) autoRaceV4Enabled = state end)
createToggleFeature(settingsPage, nil, "Anti AFK", "Prevent AFK disconnections automatically", 32, autoAfkEnabled, function(state) autoAfkEnabled = state end)
createInputFeature(settingsPage, "Fly Speed (60-350)", flySpeed, 3, function(val)
    flySpeed = math.clamp(math.floor(tonumber(val) or 190), 60, 350)
end)
createInputFeature(settingsPage, "Fast Attack Targets", maxAttackTargets, 13, function(val)
    maxAttackTargets = math.clamp(math.floor(tonumber(val) or 2), 1, 6)
end)
createToggleFeature(settingsPage, nil, "Fast Attack Players", "Fast-attack nearby players alongside mobs", 14, FA.playerEnabled, function(state) FA.playerEnabled = state end)
createToggleFeature(settingsPage, "AutoClickGunToggle", "Auto Click Gun", "Use virtual mouse input to fire at mobs (select Weapon = Gun and enable Fast Attack)", 14, true, function(state)
    FA.gunClickEnabled = state
end)
createToggleFeature(settingsPage, nil, "Auto Fast Attack", "Enable Fast Attack while farming and attack targets in range automatically", 12, FA.auto, function(state)
    FA.auto = state
    if state then fastAttackEnabled = true end
end)
createInputFeature(settingsPage, "Fast Attack Players Targets", FA.maxPlayers, 15, function(val)
    FA.maxPlayers = math.clamp(math.floor(tonumber(val) or 2), 1, 4)
end)
createInputFeature(settingsPage, "Underwater City Gate Wait (s)", Q.PORTAL_WAIT, 33, function(val)
    Q.PORTAL_WAIT = math.clamp(tonumber(val) or 6, 1, 30)
end)

_G.MinhHubLoad(46, "Loading Redeem Code...")
-- =========================================================
--                      REDEEM CODE
-- =========================================================
-- Hàng "Redeem Code" + nút "Click" (tab Config).
--  * Ô nhập có chữ  -> chỉ nhập đúng code đó.
--  * Ô nhập để trống -> nhập lần lượt toàn bộ code trong REDEEM_CODES.
-- Code hết hạn sẽ bị server từ chối (không gây lỗi). Bạn tự thêm/xoá code trong bảng bên dưới.
-- Bọc trong hàm ẩn danh để không tốn thêm biến local ở cấp cao nhất (giới hạn 200 local của Luau).
;(function()
    local REDEEM_CODES = {
        "Sub2Fer999", "Enyu_is_Pro", "Magicbus", "JCWK", "Starcodeheo",
        "Bluxxy", "fudd10_v2", "Sub2UncleKizaru", "TantaiGaming", "kittgaming",
        "Axiore", "StrawHatMaine", "Sub2Daigrock", "Sub2OfficialNoobie",
        "SUB2GAMERROBOT_EXP1", "SUB2NOOBMASTER123", "THEGREATACE", "BIGNEWS",
    }
    local REDEEM_DELAY = 0.7   -- giây chờ giữa 2 code (tránh bị server chặn spam)

    local redeemBusy = false
    local statusLabel, clickBtn, codeBox

    local function notify(text)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Redeem Code", Text = text, Duration = 5,
            })
        end)
    end

    local function setStatus(text)
        if statusLabel then statusLabel.Text = text end
    end

    -- Gửi 1 code lên server (có timeout để không treo vĩnh viễn)
    local function redeemOne(code)
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local remote  = remotes and remotes:FindFirstChild("Redeem")
        if not remote then return false, "Không tìm thấy Remotes.Redeem" end

        local done, ok, res = false, false, nil
        _G.MHSpawn(function()
            ok, res = pcall(function() return remote:InvokeServer(code) end)
            done = true
        end)

        local t0 = tick()
        while not done and tick() - t0 < 6 do task.wait(0.05) end
        if not done then return false, "Server không phản hồi" end
        if not ok then return false, tostring(res) end
        return true, res
    end

    local function redeemCodes(list)
        if redeemBusy then return end
        redeemBusy = true
        clickBtn.Text = "..."

        local sent = 0
        pcall(function()
            for i, code in ipairs(list) do
                setStatus("Đang nhập " .. i .. "/" .. #list .. ": " .. code)
                local ok, res = redeemOne(code)
                if ok then sent = sent + 1 end
                print("[Redeem]", code, "->", ok and tostring(res) or ("LỖI: " .. tostring(res)))
                task.wait(REDEEM_DELAY)
            end
        end)

        setStatus("Xong: đã gửi " .. sent .. "/" .. #list .. " code (xem kết quả ở F9)")
        notify("Đã gửi " .. sent .. "/" .. #list .. " code. Xem F9 để biết code nào nhận được.")
        clickBtn.Text = "Click"
        redeemBusy = false
    end

    -- Config có nhiều thẻ -> cho tự giãn vùng cuộn để không bị cắt mất thẻ cuối
    settingsPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
    settingsPage.CanvasSize = UDim2.new(0, 0, 0, 0)

    -- Ô nhập code tuỳ chọn
    local inputCard = Instance.new("Frame")
    inputCard.Name = "RedeemInputCard"
    inputCard.Size = UDim2.new(1, 0, 0, 38)
    inputCard.BackgroundColor3 = BANANA_CARD
    inputCard.LayoutOrder = 51
    inputCard.Parent = settingsPage
    addCorner(inputCard, 6)
    addStroke(inputCard, BANANA_CARD_BORDER, 1).Transparency = 0.35

    local inputTitle = Instance.new("TextLabel")
    inputTitle.Size = UDim2.new(0.4, 0, 1, 0)
    inputTitle.Position = UDim2.new(0, 12, 0, 0)
    inputTitle.BackgroundTransparency = 1
    inputTitle.Text = "Enter code (optional)"
    inputTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    inputTitle.TextSize = 12
    inputTitle.Font = Enum.Font.GothamMedium
    inputTitle.TextXAlignment = Enum.TextXAlignment.Left
    inputTitle.Parent = inputCard

    codeBox = Instance.new("TextBox")
    codeBox.Size = UDim2.new(0.55, -12, 0, 26)
    codeBox.Position = UDim2.new(0.45, 0, 0.5, -13)
    codeBox.BackgroundColor3 = BANANA_SIDEBAR
    codeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    codeBox.PlaceholderText = "Leave blank = redeem all"
    codeBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
    codeBox.Text = ""
    codeBox.TextSize = 12
    codeBox.Font = Enum.Font.GothamMedium
    codeBox.ClearTextOnFocus = false
    codeBox.Parent = inputCard
    addCorner(codeBox, 6)
    local boxStroke = addStroke(codeBox, BANANA_CARD_BORDER, 1)
    codeBox.Focused:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.12), {Color = BANANA_YELLOW}):Play()
    end)
    codeBox.FocusLost:Connect(function()
        TweenService:Create(boxStroke, TweenInfo.new(0.12), {Color = BANANA_CARD_BORDER}):Play()
    end)

    -- Hàng "Redeem Code" + nút "Click"
    local row = Instance.new("Frame")
    row.Name = "RedeemRow"
    row.Size = UDim2.new(1, 0, 0, 50)
    row.BackgroundColor3 = BANANA_CARD
    row.LayoutOrder = 52
    row.Parent = settingsPage
    addCorner(row, 8)
    addStroke(row, BANANA_CARD_BORDER, 1).Transparency = 0.35

    local rowTitle = Instance.new("TextLabel")
    rowTitle.Size = UDim2.new(1, -110, 0, 20)
    rowTitle.Position = UDim2.new(0, 12, 0, 6)
    rowTitle.BackgroundTransparency = 1
    rowTitle.Text = "Redeem Code"
    rowTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    rowTitle.TextSize = 12
    rowTitle.Font = Enum.Font.GothamMedium
    rowTitle.TextXAlignment = Enum.TextXAlignment.Left
    rowTitle.Parent = row

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -110, 0, 16)
    statusLabel.Position = UDim2.new(0, 12, 0, 28)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Click to redeem codes"
    statusLabel.TextColor3 = Color3.fromRGB(140, 140, 156)
    statusLabel.TextSize = 10
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    statusLabel.Parent = row

    clickBtn = Instance.new("TextButton")
    clickBtn.Size = UDim2.new(0, 84, 0, 30)
    clickBtn.Position = UDim2.new(1, -96, 0.5, -15)
    clickBtn.BackgroundColor3 = BANANA_YELLOW
    clickBtn.Text = "Click"
    clickBtn.TextColor3 = BANANA_TEXT_ON
    clickBtn.TextSize = 12
    clickBtn.Font = Enum.Font.GothamBold
    clickBtn.AutoButtonColor = false
    clickBtn.Parent = row
    addCorner(clickBtn, 8)
    addStroke(clickBtn, Color3.fromRGB(150, 118, 20), 1.5)

    clickBtn.MouseEnter:Connect(function()
        TweenService:Create(clickBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255, 226, 110)}):Play()
    end)
    clickBtn.MouseLeave:Connect(function()
        TweenService:Create(clickBtn, TweenInfo.new(0.12), {BackgroundColor3 = BANANA_YELLOW}):Play()
    end)

    clickBtn.MouseButton1Click:Connect(function()
        if redeemBusy then return end
        local typed = (codeBox.Text:gsub("%s+", ""))
        _G.MHSpawn(function()
            if typed ~= "" then
                redeemCodes({typed})
            else
                redeemCodes(REDEEM_CODES)
            end
        end)
    end)
end)()

-- HOÀN THIỆN GIAO DIỆN (viền thẻ, hover, thông báo)
do
    -- thẻ nào chưa có viền thì thêm viền mảnh cho đồng bộ
    for _, data in pairs(tabs) do
        for _, card in ipairs(data.Page:GetChildren()) do
            if card:IsA("Frame") and not card:FindFirstChildOfClass("UIStroke") then
                local st = addStroke(card, BANANA_CARD_BORDER, 1)
                st.Transparency = 0.35
            end
        end
        data.Page.ScrollBarImageTransparency = 0.25
    end

    -- hover cho nút đóng / thu nhỏ
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(205, 62, 62), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.12), {BackgroundColor3 = BANANA_CARD, TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
    end)
    minimizeBtn.MouseEnter:Connect(function()
        TweenService:Create(minimizeBtn, TweenInfo.new(0.12), {BackgroundColor3 = BANANA_YELLOW, TextColor3 = BANANA_TEXT_ON}):Play()
    end)
    minimizeBtn.MouseLeave:Connect(function()
        TweenService:Create(minimizeBtn, TweenInfo.new(0.12), {BackgroundColor3 = BANANA_CARD, TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
    end)

    -- thông báo nhỏ khi tải xong
    local toast = Instance.new("TextLabel")
    toast.Name = "MinhHubToast"
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.Size = UDim2.new(0, 230, 0, 34)
    toast.Position = UDim2.new(0.5, 0, 0, -50)
    toast.BackgroundColor3 = BANANA_BG
    toast.Text = "Minh Hub - Blox Fruits is ready"
    toast.TextColor3 = BANANA_YELLOW
    toast.TextSize = 12
    toast.Font = Enum.Font.GothamBold
    toast.Parent = screenGui
    addCorner(toast, 17)
    addStroke(toast, BANANA_YELLOW, 1.5)
    TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 18)}):Play()
    task.delay(3, function()
        local out = TweenService:Create(toast, TweenInfo.new(0.25), {Position = UDim2.new(0.5, 0, 0, -50)})
        out:Play()
        out.Completed:Connect(function() toast:Destroy() end)
    end)
end

-- KÉO THẢ & TOGGLE MENU
local dragging, dragInput, dragStart, startPos
local function updateInput(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then updateInput(input) end
end)

local menuVisible, isMinimized = true, false
local function toggleMenu()
    menuVisible = not menuVisible
    local scale = mainFrame:FindFirstChild("MenuScale")
    if not scale then
        mainFrame.Visible = menuVisible
        return
    end
    if menuVisible then
        scale.Scale = 0.88
        mainFrame.Visible = true
        TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = (MH and MH.maxed) and 1.25 or 1}):Play()
    else
        local t = TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.9})
        t:Play()
        t.Completed:Connect(function()
            if not menuVisible then mainFrame.Visible = false end
        end)
    end
end

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    minimizeBtn.Text = isMinimized and "+" or "—"
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = isMinimized and UDim2.new(0, MH.W, 0, MH.HEAD) or UDim2.new(0, MH.W, 0, MH.H)}):Play()
    sidebar.Visible = not isMinimized
    pagesFolder.Visible = not isMinimized
    pageTitle.Visible = not isMinimized
    for _, nm in ipairs({"SidebarLine", "TitleUnderline"}) do
        local o = mainFrame:FindFirstChild(nm)
        if o then o.Visible = not isMinimized end
    end
end)

-- Nút ▢: phóng to / thu về kích thước thường (đổi tỷ lệ cả cửa sổ)
MH.maxed = false
MH.maxBtn.MouseButton1Click:Connect(function()
    MH.maxed = not MH.maxed
    local sc = mainFrame:FindFirstChild("MenuScale")
    if sc then
        TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = MH.maxed and 1.25 or 1}):Play()
    end
end)

toggleBtn.MouseButton1Click:Connect(toggleMenu)
-- Nút ✕: hỏi xác nhận rồi XÓA hẳn menu (muốn chỉ ẩn thì dùng nút nổi toggle)
do
    local confirm = Instance.new("Frame")
    confirm.Name = "CloseConfirm"
    confirm.Visible = false
    confirm.ZIndex = 500
    confirm.Active = true
    confirm.Size = UDim2.new(1, 0, 1, 0)
    confirm.BackgroundColor3 = Color3.new(0, 0, 0)
    confirm.BackgroundTransparency = 0.45
    confirm.BorderSizePixel = 0
    confirm.Parent = mainFrame
    do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 12) c.Parent = confirm end

    local box = Instance.new("Frame")
    box.ZIndex = 501
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.new(0.5, 0, 0.5, 0)
    box.Size = UDim2.new(0, 300, 0, 138)
    box.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
    box.BorderSizePixel = 0
    box.Parent = confirm
    do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 12) c.Parent = box end
    do local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(205, 62, 62) st.Thickness = 1.5 st.Transparency = 0.2 st.Parent = box end

    local function lbl(txt, size, font, color, y, h)
        local l = Instance.new("TextLabel")
        l.ZIndex = 502
        l.BackgroundTransparency = 1
        l.Position = UDim2.new(0, 14, 0, y)
        l.Size = UDim2.new(1, -28, 0, h)
        l.Text = txt
        l.TextSize = size
        l.Font = font
        l.TextColor3 = color
        l.TextWrapped = true
        l.Parent = box
        return l
    end
    lbl("Xóa menu?", 18, Enum.Font.GothamBold, Color3.new(1, 1, 1), 14, 24)
    lbl("Tất cả chức năng sẽ được tắt và menu bị xóa. Muốn dùng lại chỉ cần chạy lại script.", 12, Enum.Font.Gotham, Color3.fromRGB(190, 194, 208), 44, 40)

    local function btn(txt, x, color)
        local b = Instance.new("TextButton")
        b.ZIndex = 502
        b.AutoButtonColor = true
        b.Position = UDim2.new(0, x, 1, -42)
        b.Size = UDim2.new(0.5, -20, 0, 30)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Text = txt
        b.TextSize = 13
        b.Font = Enum.Font.GothamBold
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Parent = box
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = b
        return b
    end
    local noBtn  = btn("Hủy", 14, Color3.fromRGB(52, 56, 72))
    local yesBtn = btn("Xóa menu", 0, Color3.fromRGB(205, 62, 62))
    yesBtn.Position = UDim2.new(0.5, 6, 1, -42)

    closeBtn.MouseButton1Click:Connect(function() confirm.Visible = true end)
    noBtn.MouseButton1Click:Connect(function() confirm.Visible = false end)
    yesBtn.MouseButton1Click:Connect(function()
        yesBtn.Active = false
        -- TẮT TẤT CẢ chức năng đang bật (gọi callback tắt của từng toggle)
        for _, tg in ipairs(Q.allToggles or {}) do
            pcall(function() if tg.isOn() then tg.off() end end)
        end
        -- tắt nốt các cờ _G dạng true/false còn sót (trừ cờ nội bộ của hub)
        pcall(function()
            for k, v in pairs(_G) do
                if v == true and type(k) == "string" and not k:find("^MinhHub") and not k:find("^MH") then
                    _G[k] = false
                end
            end
        end)
        task.wait(0.4)  -- cho các luồng kịp thấy cờ đã tắt
        -- dừng mọi vòng lặp MHSpawn + cho phép chạy lại script ngay (không cần rejoin)
        _G.MHGen = (_G.MHGen or 0) + 1
        _G.MinhHubAlive = nil
        _G.MinhHubReady = false
        _G.MinhHubMenuGui = nil
        pcall(function()
            local sc = mainFrame:FindFirstChild("MenuScale")
            if sc then
                local t = TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.85})
                t:Play()
                t.Completed:Wait()
            end
        end)
        pcall(function() screenGui:Destroy() end)
    end)
end

-- NOCLIP LOGIC
RunService.Stepped:Connect(function()
    if autoFarmEnabled or autoFarmMaterialEnabled or autoRaidEnabled or _G.Dungeon or _G.AutoLawRaid or autoChestEnabled or _G.FruitPickupBusy or _G.PirateRaidBusy or _G.EliteHunter or _G.TyrantFarm or _G.TyrantSummon or (Q.SUB and Q.SUB.force) or (_G.__FlyN or 0) > 0 or _G.BuyMeleeActive == true then
        local character = LocalPlayer.Character
        if character then
            local nc = Q.NC
            if not nc then nc = { parts = {}, at = 0 }; Q.NC = nc end
            -- chỉ quét lại danh sách part mỗi 0.75s (trước đây quét mỗi khung hình -> giật)
            if nc.char ~= character or tick() - nc.at > 0.75 then
                nc.char, nc.at, nc.parts = character, tick(), {}
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then nc.parts[#nc.parts + 1] = part end
                end
            end
            for _, part in ipairs(nc.parts) do
                if part.Parent and part.CanCollide then part.CanCollide = false end
            end
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end
end)

local function AutoHaki()
    local character = LocalPlayer.Character
    if character and not character:FindFirstChild("HasBuso") then
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local commF = remotes and remotes:FindFirstChild("CommF_")
        if commF then
            pcall(function()
                commF:InvokeServer("Buso")
            end)
        end
    end
end

-- =========================================================
-- AUTO OBSERVATION HAKI / INSTINCT
-- PC: phím E. Giữ một lần nhấn cho tới khi UI xác nhận bật,
-- tránh spam E làm Haki bật/tắt liên tục.
-- =========================================================
-- FIX: bản cũ phụ thuộc vào ScreenGui.ImageLabel để biết Haki đã bật chưa. Nếu UI này không đúng
-- với bản game hiện tại thì script tưởng "chưa bật" và cứ nhấn E mỗi 2 giây -> phím E là nút BẬT/TẮT
-- nên Haki bật rồi tắt liên tục. Giờ: gửi lệnh "Ken = true" (chỉ BẬT, không toggle) và nhớ trạng thái
-- theo từng nhân vật; chỉ dùng phím E tối đa 1 lần / lần hồi sinh nếu game không có remote CommE.
-- ---------------------------------------------------------
-- QUÉT TRẠNG THÁI HAKI QUAN SÁT: kiểm tra nhiều dấu hiệu (không chỉ 1 UI cố định)
--   1) UI cũ: PlayerGui.ScreenGui.ImageLabel đang hiện
--   2) Nhân vật có child / attribute tên Ken, Observation, Instinct...
--   3) PlayerGui có GUI đang hiện với tên Ken / Observation / Instinct...
-- ---------------------------------------------------------
Q.OBS_NAMES = {
    ken = true, kenactive = true, kenon = true, kenicon = true, kenhaki = true,
    observation = true, observationhaki = true, observationactive = true,
    instinct = true, instincthaki = true,
}
function Q.obsNameHit(n)
    local k = (tostring(n):lower():gsub("[%s_%-]", ""))
    return Q.OBS_NAMES[k] == true
end

Q.obsGuiCache = { at = 0, hit = nil }

function Q.scanObservation()
    -- Ưu tiên "dấu hiệu đã học" (tự hiệu chuẩn) -> chính xác theo đúng bản game đang chơi
    local learned, lwhy = Q.obsLearnedActive()
    if learned ~= nil then return learned, lwhy end

    local char = LocalPlayer.Character
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if Q.obsNameHit(v.Name) then return true, "Character." .. v.Name end
        end
        local function checkAttrs(inst, label)
            local okA, attrs = pcall(function() return inst:GetAttributes() end)
            if okA and attrs then
                for k, val in pairs(attrs) do
                    if Q.obsNameHit(k) and val ~= false and val ~= 0 and val ~= nil then
                        return true, label .. " attr " .. tostring(k)
                    end
                end
            end
        end
        local r, why = checkAttrs(char, "Character")
        if r then return true, why end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            r, why = checkAttrs(hum, "Humanoid")
            if r then return true, why end
        end
    end

    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        -- UI cũ
        local sg = pg:FindFirstChild("ScreenGui")
        local ind = sg and sg:FindFirstChild("ImageLabel")
        if ind and ind.Visible ~= false then return true, "PlayerGui.ScreenGui.ImageLabel" end

        -- quét toàn bộ PlayerGui (cache 1.5s cho nhẹ)
        if tick() - Q.obsGuiCache.at > 1.5 then
            Q.obsGuiCache.at = tick()
            Q.obsGuiCache.hit = nil
            for _, v in ipairs(pg:GetDescendants()) do
                if v:IsA("GuiObject") and Q.obsNameHit(v.Name) and Q.submergedGuiVisible(v, pg) then
                    Q.obsGuiCache.hit = v:GetFullName()
                    break
                end
            end
        end
        if Q.obsGuiCache.hit then return true, Q.obsGuiCache.hit end
    end
    return false, "không thấy dấu hiệu nào"
end

local function isObservationActive()
    local on = Q.scanObservation()
    return on
end

-- Gọi tay trong executor: _G.CheckObservation() -> in kết quả quét + các GUI nghi ngờ
_G.CheckObservation = function()
    Q.obsGuiCache.at = 0
    local on, why = Q.scanObservation()
    print("[Observation] Hiệu chuẩn:", Q.OBS.result)
    print(("[Observation] %s | %s | autoObservation=%s | CommE=%s"):format(
        on and "ĐÃ BẬT" or "CHƯA BẬT", tostring(why), tostring(autoObservationEnabled),
        tostring(ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommE") ~= nil)))
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, v in ipairs(pg:GetDescendants()) do
            if v:IsA("GuiObject") then
                local n = v.Name:lower()
                if (n:find("ken") or n:find("observ") or n:find("instinct")) and Q.submergedGuiVisible(v, pg) then
                    print("   GUI nghi ngờ:", v:GetFullName())
                end
            end
        end
    end
    return on
end

local function pressEOnce()
    if okVIM and VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    elseif okVU and VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:SetKeyDown("0x65")
            task.wait(0.1)
            VirtualUser:SetKeyUp("0x65")
        end)
    end
end

-- =========================================================
-- TỰ HỌC DẤU HIỆU "HAKI QUAN SÁT ĐANG BẬT"
-- Script chụp ảnh nhanh (GUI đang hiện + vật thể/attribute trên nhân vật) khi
-- Haki TẮT và khi BẬT, rồi lấy phần khác nhau làm "chữ ký". Sau đó chỉ cần so
-- chữ ký là biết Haki đang bật hay không, không phụ thuộc tên UI cố định.
--   Bước A: gửi CommE "Ken", true  -> có gì mới xuất hiện không?
--   Bước B: gửi CommE "Ken", false -> có gì biến mất không? (rồi bật lại)
--   Bước C: nhấn phím E            -> có gì thay đổi không?
-- =========================================================
Q.OBS = { sig = nil, calibrated = false, calibrating = false, lastCal = 0,
          snapAt = 0, snapHits = 0, result = "Chưa hiệu chuẩn", via = nil, method = nil, lastAction = nil }

function Q.obsSnapshot()
    local set = {}
    local char = LocalPlayer.Character
    if char then
        for _, v in ipairs(char:GetDescendants()) do
            set["C:" .. v.ClassName .. ":" .. v.Name] = true
        end
        local okA, attrs = pcall(function() return char:GetAttributes() end)
        if okA then for k, val in pairs(attrs) do set["CA:" .. k .. "=" .. tostring(val)] = true end end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local okH, ha = pcall(function() return hum:GetAttributes() end)
            if okH then for k, val in pairs(ha) do set["HA:" .. k .. "=" .. tostring(val)] = true end end
        end
    end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, v in ipairs(pg:GetDescendants()) do
            if v:IsA("GuiObject") and Q.submergedGuiVisible(v, pg) then
                set["G:" .. v:GetFullName()] = true
            end
        end
    end
    return set
end

-- Chụp 2 lần cách 0.4s: trả về (tập ổn định, hợp 2 lần chụp)
function Q.obsStable()
    local a = Q.obsSnapshot()
    task.wait(0.4)
    local b = Q.obsSnapshot()
    local stable, union = {}, {}
    for k in pairs(a) do union[k] = true; if b[k] then stable[k] = true end end
    for k in pairs(b) do union[k] = true end
    return stable, union
end

-- Các key có trong `stable` nhưng không có trong `unionBefore`
function Q.obsAdded(stable, unionBefore)
    local list = {}
    for k in pairs(stable) do if not unionBefore[k] then table.insert(list, k) end end
    return list
end

function Q.obsPickSig(list)
    table.sort(list, function(x, y)
        local function score(k)
            local l = string.lower(k)
            if l:find("ken", 1, true) or l:find("observ", 1, true) or l:find("haki", 1, true) or l:find("instinct", 1, true) then return 0 end
            return 1
        end
        local sx, sy = score(x), score(y)
        if sx ~= sy then return sx < sy end
        return x < y
    end)
    local out = {}
    for i = 1, math.min(#list, 40) do out[i] = list[i] end
    return out
end

-- Dùng chữ ký đã học: true / false, hoặc nil nếu chưa học được
function Q.obsLearnedActive()
    local sig = Q.OBS.sig
    if not sig or #sig == 0 then return nil end
    if tick() - Q.OBS.snapAt > 1.5 then
        Q.OBS.snapAt = tick()
        local snap = Q.obsSnapshot()
        local hits = 0
        for _, k in ipairs(sig) do if snap[k] then hits = hits + 1 end end
        Q.OBS.snapHits = hits
    end
    local need = math.max(1, math.ceil(#sig * 0.6))
    return Q.OBS.snapHits >= need, ("dấu hiệu đã học %d/%d"):format(Q.OBS.snapHits, #sig)
end

function Q.obsHits(sig, set)
    local hits = 0
    for _, k in ipairs(sig) do if set[k] then hits = hits + 1 end end
    return hits, math.max(1, math.ceil(#sig * 0.6))
end

function Q.obsCalibrate()
    if Q.OBS.calibrating then return end
    Q.OBS.calibrating = true
    Q.OBS.lastCal = tick()
    Q.OBS.method = nil
    Q.OBS.sig = nil
    Q.OBS.result = "Đang học dấu hiệu Haki..."
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local commE = remotes and remotes:FindFirstChild("CommE")
    local function fire(v)
        if commE then pcall(function() commE:FireServer("Ken", v) end) end
    end
    local function settle() task.wait(1.3) end

    -- Kiểm chứng: dùng `toggleOff()` thì chữ ký phải biến mất, dùng `toggleOn()` thì phải hiện lại.
    local function validate(sig, toggleOff, toggleOn)
        toggleOff(); settle()
        local sOff = Q.obsStable()
        local h1, need = Q.obsHits(sig, sOff)
        toggleOn(); settle()
        local sOn = Q.obsStable()
        local h2 = Q.obsHits(sig, sOn)
        return h1 < need and h2 >= need
    end

    local ok, err = pcall(function()
        local sPrev, uPrev = Q.obsStable()

        -- ===== Phương pháp 1: remote CommE "Ken" =====
        if commE then
            fire(true); settle()
            local s1, u1 = Q.obsStable()
            local added = Q.obsAdded(s1, uPrev)
            if #added > 0 then
                local sig = Q.obsPickSig(added)
                if validate(sig, function() fire(false) end, function() fire(true) end) then
                    Q.OBS.sig, Q.OBS.method = sig, "remote"
                    return
                end
            else
                fire(false); settle()
                local s2, u2 = Q.obsStable()
                local removed = Q.obsAdded(s1, u2)
                if #removed > 0 then
                    local sig = Q.obsPickSig(removed)
                    -- đang TẮT: bật lại và kiểm chứng
                    fire(true); settle()
                    local s3 = Q.obsStable()
                    local h, need = Q.obsHits(sig, s3)
                    if h >= need and validate(sig, function() fire(false) end, function() fire(true) end) then
                        Q.OBS.sig, Q.OBS.method = sig, "remote"
                        return
                    end
                end
                fire(true); settle()
            end
            sPrev, uPrev = Q.obsStable()
        end

        -- ===== Phương pháp 2: phím E (nút bật/tắt) =====
        pressEOnce(); settle()
        local s4, u4 = Q.obsStable()
        local addedE = Q.obsAdded(s4, uPrev)
        local removedE = Q.obsAdded(sPrev, u4)
        if #addedE > 0 and #addedE >= #removedE then
            local sig = Q.obsPickSig(addedE)       -- vừa BẬT
            if validate(sig, pressEOnce, pressEOnce) then
                Q.OBS.sig, Q.OBS.method = sig, "E"
                return
            end
        elseif #removedE > 0 then
            local sig = Q.obsPickSig(removedE)     -- vừa TẮT -> bật lại
            pressEOnce(); settle()
            local s5 = Q.obsStable()
            local h, need = Q.obsHits(sig, s5)
            if h >= need and validate(sig, pressEOnce, pressEOnce) then
                Q.OBS.sig, Q.OBS.method = sig, "E"
                return
            end
        end
    end)

    Q.OBS.calibrating = false
    if Q.OBS.sig and #Q.OBS.sig > 0 then
        Q.OBS.calibrated = true
        Q.OBS.result = ("Đã học %d dấu hiệu, bật bằng: %s (đã kiểm chứng)"):format(#Q.OBS.sig, tostring(Q.OBS.method))
        print("[Observation] " .. Q.OBS.result)
        for i = 1, math.min(#Q.OBS.sig, 8) do print("   dấu hiệu:", Q.OBS.sig[i]) end
    else
        Q.OBS.calibrated = false
        Q.OBS.result = "Không học được dấu hiệu (có thể chưa mở khoá Haki quan sát?), thử lại sau 60s"
        warn("[Observation] " .. Q.OBS.result .. (ok and "" or (" | lỗi: " .. tostring(err))))
    end
end

-- Gọi tay: học lại dấu hiệu (nên chạy khi đang đứng yên, không combat)
_G.CalibrateObservation = function()
    Q.OBS.sig, Q.OBS.calibrated, Q.OBS.snapAt, Q.OBS.method = nil, false, 0, nil
    _G.MHSpawn(Q.obsCalibrate)
end

-- Một lượt cố bật Haki, chạy nền (không chặn vòng lặp chính)
function Q.observationAttempt(char)
    local st = observationState
    st.attempts = (st.attempts or 0) + 1
    local method = Q.OBS.method
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local commE = remotes and remotes:FindFirstChild("CommE")

    if method == "E" then
        -- Đã xác nhận phím E có tác dụng và quét được trạng thái -> an toàn để nhấn khi đang TẮT
        Q.OBS.lastAction = "Nhấn phím E (lần " .. st.attempts .. ")"
        pressEOnce()
        task.wait(1.2)
        if LocalPlayer.Character == char then st.on = Q.scanObservation() end
        return
    end

    -- method == "remote" hoặc chưa học được: remote chỉ-BẬT, gửi lại nhiều lần không làm tắt
    if commE then
        Q.OBS.lastAction = "Gửi CommE Ken=true (lần " .. st.attempts .. ")"
        pcall(function() commE:FireServer("Ken", true) end)
        task.wait(0.8)
        if LocalPlayer.Character == char and Q.scanObservation() then st.on = true return end
    end

    -- Chưa học được gì: nhấn E tối đa 1 lần / lần hồi sinh (E là nút bật/tắt)
    if method == nil and not st.pressedE and (st.attempts >= 3 or not commE) then
        st.pressedE = true
        Q.OBS.lastAction = "Nhấn phím E 1 lần (chưa học được dấu hiệu)"
        pressEOnce()
        task.wait(1.0)
    end
end

ensureObservation = function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChildOfClass("Humanoid") then return false end

    local st = observationState
    if st.char ~= char then -- nhân vật mới (hồi sinh) -> Haki đã mất, reset trạng thái
        st.char, st.on, st.lastTry, st.tries = char, false, 0, 0
        st.attempts, st.pressedE, st.busy = 0, false, false
    end

    -- Lần đầu (hoặc học lại): tự học dấu hiệu "Haki đang bật" trước
    if not Q.OBS.calibrated and not Q.OBS.calibrating and tick() - Q.OBS.lastCal > 60 then
        _G.MHSpawn(Q.obsCalibrate)
    end
    if Q.OBS.calibrating then return false end

    -- QUÉT: Haki đã bật chưa?
    local active = Q.scanObservation()
    if active then
        st.on = true
        return true
    end
    st.on = false

    -- Chưa bật -> thử bật (cách nhau 3s, mỗi lần chạy nền)
    if st.busy or tick() - st.lastTry < 3 then return false end
    st.lastTry = tick()
    st.busy = true
    _G.MHSpawn(function()
        pcall(Q.observationAttempt, char)
        st.busy = false
    end)
    return false
end

LocalPlayer.CharacterAdded:Connect(function()
    observationState.lastTry = 0
    task.delay(1.5, function()
        if autoObservationEnabled then
            pcall(ensureObservation)
        end
    end)
end)

_G.MHSpawn(function()
    task.wait(1)
    while true do
        task.wait(0.75)
        pcall(function()
            -- Giới hạn tần suất gọi remote / bấm phím để server không kick vì spam
            local nowT = tick()
            Q.LIMIT = Q.LIMIT or { haki = 0, v3 = 0, v4 = 0 }

            if autoHakiEnabled and nowT - Q.LIMIT.haki >= 3 then
                Q.LIMIT.haki = nowT
                AutoHaki()
            end

            if autoObservationEnabled then
                ensureObservation()
            end

            if autoRaceV3Enabled and nowT - Q.LIMIT.v3 >= 5 then
                Q.LIMIT.v3 = nowT
                local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                if commF then commF:InvokeServer("ActivateAbility") end
                if okVIM and VirtualInputManager then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.T, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.T, false, game)
                end
            end

            if autoRaceV4Enabled and okVIM and VirtualInputManager and nowT - Q.LIMIT.v4 >= 5 then
                Q.LIMIT.v4 = nowT
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Y, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Y, false, game)
            end
        end)
    end
end)

-- HÀM BAY THẲNG DÙNG CHUNG (Auto Pickup Fruit + Auto Random Fruit)
-- Mỗi frame (Heartbeat) tự tính vị trí kế tiếp trên ĐƯỜNG THẲNG tới đích rồi đặt CFrame và xoá vận tốc.
-- Không dùng Tween nên không bị trọng lực / Humanoid kéo lệch, tốc độ đều, bám theo mục tiêu nếu nó di chuyển.
-- getTarget(): trả về Vector3 đích (nil = dừng).  keepGoing(): trả false để dừng ngay.
-- Trả về true nếu đã tới nơi (cách đích <= arriveDist).
_G.FlyStraight = function(getTarget, speed, keepGoing, arriveDist)
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end

    stopAllFlying() -- huỷ mọi Tween đang điều khiển nhân vật
    local pos = hrp.Position
    local t0 = tick()
    local arrived = false

    local ok = pcall(function()
        while (not keepGoing or keepGoing()) and tick() - t0 < 90 do
            local dt = RunService.Heartbeat:Wait()
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if not r or not h or h.Health <= 0 then return end

            local target = getTarget()
            if not target then return end

            -- server kéo nhân vật lại xa > 40 studs -> lấy vị trí thật làm gốc rồi bay tiếp
            if (r.Position - pos).Magnitude > 40 then pos = r.Position end

            local delta = target - pos
            local dist = delta.Magnitude
            if dist <= (arriveDist or 3) then arrived = true; return end

            pos = pos + delta.Unit * math.min(dist, speed * dt)
            local flat = Vector3.new(delta.X, 0, delta.Z)
            local look = flat.Magnitude > 0.1 and (pos + flat.Unit) or (pos + r.CFrame.LookVector)
            r.CFrame = CFrame.new(pos, look)
            r.AssemblyLinearVelocity  = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            for _, part in ipairs(c:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end)

    pcall(function()
        local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if r then r.AssemblyLinearVelocity = Vector3.zero end
    end)
    return ok and arrived
end

-- LOGIC AUTO RANDOM FRUIT v3 (ZIOLES' GACHA BOX - SEA 1/2/3)
-- Luồng giống đúng ảnh bạn gửi: bay tới Zioles -> hộp thoại "Random Fruit" -> cửa sổ "Zioles' Gacha Box" -> nút giá tiền.
-- Các lỗi đã sửa so với v2:
-- 1) Bấm nút trúng vị trí: v2 luôn cộng thêm GuiInset nên bấm lệch xuống dưới, dễ bấm nhầm nút "Nevermind". Giờ chỉ cộng
--    khi ScreenGui không IgnoreGuiInset; ưu tiên kích hoạt thẳng sự kiện của nút (getconnections/firesignal), chuột ảo chỉ là dự phòng.
-- 2) Mọi lời gọi remote đều có timeout: InvokeServer có thể treo vĩnh viễn làm đứng cả vòng lặp mua.
-- 3) Tìm NPC theo tên Model, DisplayName của Humanoid và chữ trên bảng tên ("Blox Fruit Gacha"/"Zioles"); nếu chưa thấy
--    (NPC chưa tải) thì bay tới khu vực dự phòng của từng Sea rồi tìm lại.
-- 4) Bay tới NPC bằng bay thẳng từng frame (ổn định, không dùng Tween).
-- 5) Báo rõ trên tab Gacha: đang ở bước nào, nút nào đang hiện, lời thoại của NPC (vd. chưa đủ 2 giờ / chưa đủ level).
_G.MHSpawn(function()
    local RF_DEBUG             = true
    local RF_COOLDOWN          = 7200 + 30
    local RF_RETRY             = 60
    local RF_RETRY_UNCONFIRMED = 300
    local RF_CALL_TIMEOUT      = 6

    -- Điểm tới dự phòng khi chưa thấy NPC (khu vực của NPC theo từng Sea; gần đúng)
    local NPC_AREA = {
        [1] = Vector3.new(-690.3, 15.1, 1582.2),     -- Middle Town (Zioles chuyển về đây từ Update 30)
        [2] = Vector3.new(-379.6, 73.0, 297.4),      -- Café
        [3] = Vector3.new(-12471.2, 374.9, -7551.7), -- Mansion
    }
    local seaIndex = World1 and 1 or (World2 and 2 or 3)

    local nextBuyAt  = 0
    local wasEnabled = false
    _G.RandomFruitStatus = "Disabled"

    local function setStatus(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        local txt = table.concat(parts, " ")
        if txt ~= _G.RandomFruitStatus then
            _G.RandomFruitStatus = txt
            if RF_DEBUG then print("[RandomFruit]", txt) end
        end
    end

    local function describe(v)
        if type(v) == "table" then
            local parts = {}
            for k, val in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(val) end
            return "{" .. table.concat(parts, ", ") .. "}"
        end
        return tostring(v)
    end

    -- InvokeServer có timeout. Trả về: ok, kết quả | lý do lỗi
    local function invoke(remote, ...)
        local args = table.pack(...)
        local done, ok, res = false, false, nil
        _G.MHSpawn(function()
            ok, res = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end)
            done = true
        end)
        local t0 = tick()
        while not done and tick() - t0 < RF_CALL_TIMEOUT do task.wait(0.1) end
        if not done then return false, "timeout " .. RF_CALL_TIMEOUT .. "s (server không trả lời)" end
        return ok, res
    end

    local function getCommF()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local commF = remotes and remotes:FindFirstChild("CommF_")
        if commF and commF:IsA("RemoteFunction") then return commF end
        return nil
    end

    local function getBeli()
        local data = LocalPlayer:FindFirstChild("Data")
        local beli = data and data:FindFirstChild("Beli")
        return beli and tonumber(beli.Value) or nil
    end

    -- Dùng chung với Auto Store Fruit
    _G.IsFruitTool = function(tool)
        if not tool or not tool:IsA("Tool") then return false end
        if tool.ToolTip == "Blox Fruit" then return true end
        if tool:FindFirstChild("Fruit") ~= nil then return true end
        if tool:GetAttribute("Fruit") ~= nil or tool:GetAttribute("OriginalName") ~= nil then return true end
        return string.find(string.lower(tool.Name), "fruit", 1, true) ~= nil
    end

    local function snapshotFruitTools()
        local snap = {}
        local function scan(container)
            if not container then return end
            for _, tool in ipairs(container:GetChildren()) do
                if _G.IsFruitTool(tool) then snap[tool.Name] = (snap[tool.Name] or 0) + 1 end
            end
        end
        scan(LocalPlayer:FindFirstChild("Backpack"))
        scan(LocalPlayer.Character)
        return snap
    end

    local function purchaseConfirmed(beliBefore, snapBefore)
        local beliNow = getBeli()
        if beliBefore and beliNow and beliNow < beliBefore then
            return true, "Beli giảm " .. tostring(beliBefore - beliNow)
        end
        for name, n in pairs(snapshotFruitTools()) do
            if n > (snapBefore[name] or 0) then return true, "Nhận fruits: " .. name end
        end
        return false
    end

    local function waitConfirm(beliBefore, snapBefore, seconds)
        local deadline = tick() + seconds
        repeat
            local ok, why = purchaseConfirmed(beliBefore, snapBefore)
            if ok then return true, why end
            task.wait(0.1)
        until tick() >= deadline
        return false
    end

    -- ===== CÁCH 1: REMOTE (không cần bay) =====
    local function tryRemote()
        local beliBefore, snapBefore = getBeli(), snapshotFruitTools()
        local notes = {}

        local commF = getCommF()
        if commF then
            local okC, resC = invoke(commF, "Cousin", "Check")
            notes[#notes + 1] = "Check=" .. (okC and describe(resC) or "lỗi")
            task.wait(0.05)
            local okB, resB = invoke(commF, "Cousin", "Buy")
            notes[#notes + 1] = "Buy=" .. (okB and describe(resB) or tostring(resB))
            setStatus("Remote:", table.concat(notes, " | "))
            local ok, why = waitConfirm(beliBefore, snapBefore, 2.5)
            if ok then return "success", why end
        else
            notes[#notes + 1] = "không thấy CommF_"
        end

        -- Remote Net mới (nếu game có): RF/GachaNetworkRF, hộp mặc định của Zioles
        local net = ReplicatedStorage:FindFirstChild("Modules")
        net = net and net:FindFirstChild("Net")
        local gachaRF = net and net:FindFirstChild("RF/GachaNetworkRF")
        if gachaRF then
            local okN, resN = invoke(gachaRF, {Context = "Purchase", BoxName = "ZiolesGacha"})
            notes[#notes + 1] = "Net=" .. (okN and describe(resN) or tostring(resN))
            setStatus("Remote:", table.concat(notes, " | "))
            local ok, why = waitConfirm(beliBefore, snapBefore, 2.5)
            if ok then return "success", why end
        end

        return "fail", table.concat(notes, " | ")
    end

    -- ===== CÁCH 2: GIAO DIỆN =====
    local function guiVisible(obj, pg)
        local g = obj
        while g and g ~= pg do
            if g:IsA("GuiObject") and not g.Visible then return false end
            if g:IsA("ScreenGui") and not g.Enabled then return false end
            g = g.Parent
        end
        return true
    end

    local function textOf(obj)
        local t = ""
        pcall(function()
            if obj:IsA("TextButton") or obj:IsA("TextLabel") then t = obj.Text end
            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then t = t .. " " .. d.Text end
            end
        end)
        return (string.gsub(string.lower(t), "<[^>]->", "")) -- bỏ thẻ rich text
    end

    -- Cache nút giao diện: PlayerGui có thể chứa hàng nghìn descendant, không quét lại toàn bộ mỗi vòng.
    local buttonCache = {}
    local cachedPlayerGui = nil
    local buttonAddedConn, buttonRemovingConn

    local function isClickButton(obj)
        return obj and (obj:IsA("TextButton") or obj:IsA("ImageButton"))
    end

    local function visibleButtons()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return {} end

        if pg ~= cachedPlayerGui then
            pcall(function() if buttonAddedConn then buttonAddedConn:Disconnect() end end)
            pcall(function() if buttonRemovingConn then buttonRemovingConn:Disconnect() end end)
            cachedPlayerGui = pg
            buttonCache = {}
            for _, d in ipairs(pg:GetDescendants()) do
                if isClickButton(d) then buttonCache[d] = true end
            end
            buttonAddedConn = pg.DescendantAdded:Connect(function(d)
                if isClickButton(d) then buttonCache[d] = true end
            end)
            buttonRemovingConn = pg.DescendantRemoving:Connect(function(d)
                if isClickButton(d) then buttonCache[d] = nil end
            end)
        end

        local out = {}
        for b in pairs(buttonCache) do
            if b.Parent and guiVisible(b, pg) and b.AbsoluteSize.X > 4 and b.AbsoluteSize.Y > 4 then
                out[#out + 1] = b
            end
        end
        return out
    end

    local function findButton(pred)
        for _, b in ipairs(visibleButtons()) do
            if pred(b) then return b end
        end
        return nil
    end

    -- Bấm nút. Cách A: kích hoạt trực tiếp sự kiện. Cách B: chuột ảo (có tính đúng GuiInset).
    local function clickButton(btn)
        local fired = false
        if typeof(getconnections) == "function" then
            -- chỉ dùng sự kiện ĐẦU TIÊN có handler: bấm 2 sự kiện cùng lúc có thể gọi mua 2 lần
            for _, sig in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down"}) do
                local okS, conns = pcall(function() return getconnections(btn[sig]) end)
                if okS and conns and #conns > 0 then
                    for _, c in ipairs(conns) do pcall(function() c:Fire() end) end
                    fired = true
                    break
                end
            end
        end
        if not fired and typeof(firesignal) == "function" then
            fired = pcall(function() firesignal(btn.Activated) end)
            if not fired then fired = pcall(function() firesignal(btn.MouseButton1Click) end) end
        end
        if fired then return "event" end

        local ok = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local sg = btn:FindFirstAncestorOfClass("ScreenGui")
            local insetY = (sg and sg.IgnoreGuiInset) and 0 or game:GetService("GuiService"):GetGuiInset().Y
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            vim:SendMouseMoveEvent(pos.X, pos.Y + insetY, game)
            task.wait(0.05)
            vim:SendMouseButtonEvent(pos.X, pos.Y + insetY, 0, true, game, 0)
            task.wait(0.06)
            vim:SendMouseButtonEvent(pos.X, pos.Y + insetY, 0, false, game, 0)
        end)
        return ok and "mouse" or nil
    end

    local function isPurchaseButton(b, cachedText)
        if string.lower(b.Name) == "purchasebutton" then return true end
        local t = cachedText or textOf(b)
        return string.match(t, "^%s*%$%s*[%d,%.]+%s*$") ~= nil -- "$444,850"
    end

    local function isRandomOption(b, cachedText)
        local t = cachedText or textOf(b)
        if string.find(t, "nevermind", 1, true) or string.find(t, "never mind", 1, true) then return false end
        return string.find(t, "random", 1, true) ~= nil or string.find(t, "gacha", 1, true) ~= nil
            or string.find(t, "ngẫu nhiên", 1, true) ~= nil or string.find(t, "ngau nhien", 1, true) ~= nil
    end

    -- Quét danh sách nút cache đúng một lần mỗi vòng; luôn ưu tiên nút mua nếu nó đã xuất hiện.
    local function findRandomFlowButtons()
        local purchase, option = nil, nil
        for _, b in ipairs(visibleButtons()) do
            local t = textOf(b)
            if isPurchaseButton(b, t) then
                purchase = b
                break
            elseif not option and isRandomOption(b, t) then
                option = b
            end
        end
        return purchase, option
    end

    local function isCloseButton(b)
        local n = string.lower(b.Name)
        if n == "close" or n == "closebutton" or n == "exitbutton" or n == "x" then return true end
        local t = textOf(b)
        return string.match(t, "^%s*[x×✕✖]%s*$") ~= nil
    end

    -- Lời thoại NPC đang hiện (để báo lý do khi không có nút Random Fruit)
    local function dialogueText()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return nil end
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") and d.Visible and guiVisible(d, pg) then
                local t = d.Text
                if #t > 25 and (string.find(t, "Zioles", 1, true) or string.find(string.lower(t), "random", 1, true)
                    or string.find(string.lower(t), "hours", 1, true)) then
                    return (string.gsub(t, "<[^>]->", ""))
                end
            end
        end
        return nil
    end

    local function listButtons()
        local names = {}
        for i, b in ipairs(visibleButtons()) do
            local t = textOf(b)
            t = string.gsub(t, "%s+", " ")
            if #t > 0 and #t < 24 then names[#names + 1] = t end
            if #names >= 6 then break end
        end
        return table.concat(names, " / ")
    end

    -- ===== Tìm NPC Zioles =====
    local function npcMatches(model)
        local n = string.lower(model.Name)
        if string.find(n, "gacha", 1, true) or string.find(n, "zioles", 1, true) or string.find(n, "cousin", 1, true) then
            return true
        end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum then
            local dn = string.lower(hum.DisplayName or "")
            if string.find(dn, "gacha", 1, true) or string.find(dn, "zioles", 1, true) then return true end
        else
            -- Không có Humanoid và tên không gợi ý NPC thì bỏ qua để tránh quét sâu model không liên quan.
            return false
        end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("TextLabel") then
                local t = string.lower(d.Text)
                if string.find(t, "blox fruit gacha", 1, true) or t == "zioles" then return true end
            end
        end
        return false
    end

    local cachedGachaNPC, cachedGachaAt = nil, 0
    local function findGachaNPC()
        if cachedGachaNPC and cachedGachaNPC.Parent and tick() - cachedGachaAt < 8 then
            return cachedGachaNPC
        end
        cachedGachaNPC = nil
        local function scan(root)
            if not root then return nil end
            for _, d in ipairs(root:GetChildren()) do
                if d:IsA("Model") and not Players:GetPlayerFromCharacter(d) and npcMatches(d) then return d end
            end
            return nil
        end
        local found = scan(workspace:FindFirstChild("NPCs"))
        if found then cachedGachaNPC, cachedGachaAt = found, tick(); return found end
        found = scan(workspace)
        if found then cachedGachaNPC, cachedGachaAt = found, tick(); return found end
        -- quét sâu (chỉ khi cần): mọi Model có Humanoid không thuộc người chơi
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Humanoid") then
                local m = d.Parent
                if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) and npcMatches(m) then
                    cachedGachaNPC, cachedGachaAt = m, tick()
                    return m
                end
            end
        end
        return nil
    end

    local flyStraight = _G.FlyStraight

    local function tryUI()
        local beliBefore, snapBefore = getBeli(), snapshotFruitTools()
        local result, detail = "fail", "Không mở được Gacha Box"

        _G.FruitPickupBusy = true  -- tạm dừng farm / cất trái trong lúc đi mua
        local okRun, err = pcall(function()
            local function wanted() return autoRandomFruitEnabled end

            -- 1) Tìm NPC (nếu chưa thấy thì bay tới khu vực của Sea rồi tìm lại)
            setStatus("Đang tìm NPC Zioles (Blox Fruit Gacha)...")
            local npc = findGachaNPC()
            if not npc then
                local area = NPC_AREA[seaIndex]
                if area then
                    setStatus("Chưa thấy NPC - bay tới khu vực Zioles (Sea " .. seaIndex .. ")...")
                    flyStraight(function() return area + Vector3.new(0, 25, 0) end, math.max(flySpeed or 190, 420), wanted, 15)
                    for _ = 1, 6 do
                        task.wait(0.25)
                        npc = findGachaNPC()
                        if npc then break end
                    end
                end
            end
            if not npc then detail = "Không thấy NPC Blox Fruit Gacha ở Sea " .. seaIndex; return end

            local function npcPos()
                local okPv, cf = pcall(function() return npc:GetPivot() end)
                return okPv and cf and cf.Position or nil
            end

            -- 2) Bay thẳng tới sát NPC (vào vòng xanh dưới chân NPC thì hội thoại tự mở)
            setStatus("Đang bay tới Zioles...")
            local arrived = flyStraight(function()
                local p = npcPos()
                return p and (p + Vector3.new(3, 0.5, 0)) or nil
            end, math.max(flySpeed or 190, 420), wanted, 2.5)
            if not wanted() then detail = "Đã tắt"; return end
            if not arrived then detail = "Không bay tới được NPC"; return end

            task.wait(0.2)
            for _, d in ipairs(npc:GetDescendants()) do
                if d:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                    pcall(fireproximityprompt, d)
                elseif d:IsA("ClickDetector") and typeof(fireclickdetector) == "function" then
                    pcall(fireclickdetector, d)
                end
            end

            -- 3) Hộp thoại -> "Random Fruit" -> nút giá tiền
            local deadline = tick() + 14
            local clickedPurchase, lastOptClick = false, 0
            while tick() < deadline and wanted() do
                local buy, opt = findRandomFlowButtons()
                if buy then
                    setStatus("Bấm nút mua trong Gacha Box (" .. textOf(buy) .. ")...")
                    local how = clickButton(buy)
                    clickedPurchase = how ~= nil
                    break
                end

                if opt and tick() - lastOptClick > 0.6 then
                    setStatus("Chọn 'Random Fruit' trong hội thoại...")
                    clickButton(opt)
                    lastOptClick = tick()
                else
                    -- Đứng sát NPC tiếp để hội thoại kịp mở; giữ nhân vật không bị trôi
                    local p, r = npcPos(), LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if p and r and (r.Position - p).Magnitude > 8 then r.CFrame = CFrame.new(p + Vector3.new(3, 0.5, 0)) end
                end
                task.wait(0.12)
            end

            if not clickedPurchase then
                local talk = dialogueText()
                local btns = listButtons()
                result = "wait"
                detail = "Không thấy nút mua sau 14s."
                    .. (talk and (" Zioles nói: \"" .. string.sub(talk, 1, 90) .. "\"") or "")
                    .. (btns ~= "" and (" Nút đang hiện: " .. btns) or "")
                return
            end

            -- 4) Chờ kết quả (có hoạt ảnh quay hộp)
            local ok, why = waitConfirm(beliBefore, snapBefore, 6.5)
            if ok then
                result, detail = "success", why
            else
                -- Nút vẫn còn -> bấm lại 1 lần bằng cách còn lại
                local again = findButton(isPurchaseButton)
                if again then
                    task.wait(0.25)
                    clickButton(again)
                    ok, why = waitConfirm(beliBefore, snapBefore, 4.5)
                end
                if ok then result, detail = "success", why
                else result, detail = "unconfirmed", "Đã bấm mua nhưng chưa thấy trái/Beli đổi (cần Lv50+, đủ tiền, cách lần mua trước ≥ 2 giờ)" end
            end

            -- 5) Đóng cửa sổ Gacha Box
            task.wait(0.25)
            local close = findButton(isCloseButton)
            if close then clickButton(close) end
        end)
        _G.FruitPickupBusy = false
        pcall(stopAllFlying)
        pcall(function()
            local c = LocalPlayer.Character
            if c then for _, part in ipairs(c:GetChildren()) do if part:IsA("BasePart") then part.CanCollide = true end end end
        end)

        if not okRun then return "fail", "Lỗi UI: " .. tostring(err) end
        return result, detail
    end

    local function raidBusy()
        return RAID_FIXED.running or RAID_FIXED.starting or autoRaidEnabled or _G.Dungeon
            or _G.PirateRaidBusy or _G.BuyMeleeActive == true
            or not Q.SmartController.canRun("fruit")
    end

    while task.wait(0.25) do
        if autoRandomFruitEnabled then
            if not wasEnabled then
                wasEnabled = true
                if tick() < nextBuyAt then
                    setStatus("⏳ Đang cooldown, còn khoảng " .. math.ceil(nextBuyAt - tick()) .. " giây")
                else
                    setStatus("ENABLED - preparing to purchase...")
                end
            end

            if tick() >= nextBuyAt and not raidBusy() then
                local status, why = tryRemote()
                if status ~= "success" then
                    local s2, why2 = tryUI()
                    if s2 == "success" then status, why = "success", why2
                    elseif s2 == "unconfirmed" then status, why = "unconfirmed", why2
                    elseif s2 == "wait" then status, why = "wait", why2
                    else status, why = "fail", "Remote: " .. tostring(why) .. " | UI: " .. tostring(why2) end
                end

                if status == "success" then
                    nextBuyAt = tick() + RF_COOLDOWN
                    setStatus("✅ Mua thành công (" .. tostring(why) .. "). Lần sau sau ~2 giờ")
                elseif status == "wait" then
                    nextBuyAt = tick() + 600
                    setStatus("⏳ " .. tostring(why) .. " - thử lại sau 10 phút")
                elseif status == "unconfirmed" then
                    nextBuyAt = tick() + RF_RETRY_UNCONFIRMED
                    setStatus("⚠️ Chưa xác nhận: " .. tostring(why) .. " - thử lại sau 5 phút")
                else
                    nextBuyAt = tick() + RF_RETRY
                    setStatus("❌ " .. tostring(why) .. " - thử lại sau " .. RF_RETRY .. "s")
                end
            end
        else
            wasEnabled = false
            _G.RandomFruitStatus = "Disabled"
        end
    end
end)

-- LOGIC AUTO FARM CHEST
_G.MHSpawn(function()
    local CollectionService = game:GetService("CollectionService")
    local attempts   = setmetatable({}, {__mode = "k"})  -- số lần thử mỗi rương
    local blacklist  = setmetatable({}, {__mode = "k"})  -- rương lỗi: bỏ qua tạm thời
    -- SMART CHEST: giữ mục tiêu hiện tại (không đổi qua lại), chấm điểm theo cụm rương,
    -- tránh rương đang có người chơi khác tranh, và ban lũy tiến cho rương lỗi.
    local failCount     = setmetatable({}, {__mode = "k"})
    local currentTarget = nil
    local collectedCnt  = 0
    _G.ChestStatus = "Idle"

    local function chestUsable(chest)
        if not chest or not chest.Parent or chest:GetAttribute("IsDisabled") then return false end
        local ban = blacklist[chest]
        return not (ban and tick() < ban)
    end

    while task.wait(0.25) do
        if not autoChestEnabled then
            currentTarget = nil
            _G.ChestStatus = "Disabled"
        end
        if autoChestEnabled and Q.SmartController.canRun("chest") then
            -- Tác vụ ưu tiên cao đang chạy thì chỉ tạm chờ; giữ toggle để tự tiếp tục sau đó.
            pcall(function()
                    local char = LocalPlayer.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    local hum  = char and char:FindFirstChildOfClass("Humanoid")
                    if not hrp or not hum or hum.Health <= 0 then return end

                    if _G.FruitPickupBusy or _G.PirateRaidBusy then return end -- nhường cho Auto Pickup Fruit / Pirate Raid

                    local function inCursedShip(pos)
                        return World2 and Q.isCursedShipPosition(pos)
                    end

                    -- Auto Farm Chest hoạt động ở bên ngoài Thuyền Ma.
                    -- Nếu đang ở trong thuyền, thoát qua cửa trong trước cả khi tìm rương.
                    -- Dùng một điểm đích ngoài thuyền để bộ điều phối cổng thực hiện đúng quy trình.
                    if inCursedShip(hrp.Position) then
                        local outsideAnchor = Vector3.new(-6500.94, 87.60, -123.19)
                        if Q.enterIfNeeded(hrp, outsideAnchor, "chest") then return end
                        char = LocalPlayer.Character
                        hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if not hrp or inCursedShip(hrp.Position) then return end
                    end

                    -- tìm rương còn dùng được, gần nhất; bỏ qua rương bên trong Thuyền Ma
                    -- để không bị đưa vào lại sau khi vừa thoát ra.
                    local bestChest, bestDist, bestPos
                    local cands = {}
                    for _, chest in ipairs(CollectionService:GetTagged("_ChestTagged")) do
                        if chestUsable(chest) then
                            local ok, cf = pcall(function() return chest:GetPivot() end)
                            if ok and cf and not inCursedShip(cf.Position) then
                                cands[#cands + 1] = {chest = chest, pos = cf.Position,
                                    d = (cf.Position - hrp.Position).Magnitude}
                            end
                        end
                    end

                    -- Giữ mục tiêu cũ nếu vẫn dùng được (tránh đổi hướng liên tục).
                    if currentTarget and chestUsable(currentTarget) then
                        for _, c in ipairs(cands) do
                            if c.chest == currentTarget then
                                bestChest, bestDist, bestPos = c.chest, c.d, c.pos
                                break
                            end
                        end
                    end

                    -- Chọn mục tiêu mới: điểm thấp = tốt (gần, nằm trong cụm nhiều rương, không bị tranh).
                    if not bestChest and #cands > 0 then
                        local others = {}
                        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                            if p ~= LocalPlayer and p.Character then
                                local pr = p.Character:FindFirstChild("HumanoidRootPart")
                                if pr then others[#others + 1] = pr.Position end
                            end
                        end
                        local bestScore
                        for _, c in ipairs(cands) do
                            local cluster = 0
                            for _, o in ipairs(cands) do
                                if o ~= c and (o.pos - c.pos).Magnitude <= 200 then cluster += 1 end
                            end
                            local score = c.d - math.min(cluster, 5) * 40
                            for _, op in ipairs(others) do
                                if (op - c.pos).Magnitude <= 80 then score += 300 break end
                            end
                            if not bestScore or score < bestScore then
                                bestScore, bestChest, bestDist, bestPos = score, c.chest, c.d, c.pos
                            end
                        end
                    end
                    currentTarget = bestChest
                    if not bestChest then
                        _G.ChestStatus = "No chest available"
                        return
                    end
                    _G.ChestStatus = ("Chest: %d collected, %d left"):format(collectedCnt, #cands)

                    -- Thùng rương ở Thuyền Ma (hoặc ở ngoài thuyền) dùng cùng bộ điều phối cổng.
                    if Q.enterIfNeeded(hrp, bestPos, "chest") then return end

                    -- bay tới rương rồi chạm vào để nhặt
                    flyTo(CFrame.new(bestPos + Vector3.new(0, 3, 0)), nil, function()
                        return autoChestEnabled and Q.SmartController.canRun("chest")
                    end)
                    if not autoChestEnabled then stopAllFlying() return end
                    if not Q.SmartController.canRun("chest") then return end
                    hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    hrp.CFrame = CFrame.new(bestPos)
                    task.wait(0.35)

                    -- chưa nhặt được sau vài lần thì bỏ qua rương này 60 giây
                    if bestChest.Parent and not bestChest:GetAttribute("IsDisabled") then
                        attempts[bestChest] = (attempts[bestChest] or 0) + 1
                        if attempts[bestChest] >= 3 then
                            -- ban lũy tiến: 60s, 120s, 240s... tối đa 300s
                            local f = (failCount[bestChest] or 0) + 1
                            failCount[bestChest] = f
                            blacklist[bestChest] = tick() + math.min(60 * 2 ^ (f - 1), 300)
                            attempts[bestChest] = 0
                            currentTarget = nil
                        end
                    else
                        attempts[bestChest] = nil
                        failCount[bestChest] = nil
                        collectedCnt += 1
                        currentTarget = nil
                    end
                end)
        end
    end
end)

-- LOGIC AUTO PICKUP FRUIT (NHẶT TRÁI ÁC QUỶ RƠI TRÊN MAP)
-- Trái spawn ngoài map là Tool nằm trực tiếp trong workspace (tên chứa "Fruit", có Handle).
-- Server chỉ cho nhặt khi nhân vật chạm vào Handle -> bay tới rồi đứng lên trái.
-- Khi đang nhặt, _G.FruitPickupBusy = true để Auto Farm / Material / Chest tạm dừng, nhặt xong tự chạy lại.
_G.MHSpawn(function()
    local attempts  = setmetatable({}, {__mode = "k"})  -- số lần thử mỗi trái
    local blacklist = setmetatable({}, {__mode = "k"})  -- trái không nhặt được: bỏ qua tạm thời

    local function fruitLog(...)
        if _G.FruitPickupDebug then
            print("[FruitPickup]", ...)
        end
    end

    local function getRoot()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    -- Đã cầm trái cùng tên (game không cho cầm trùng 1 loại) -> khỏi bay tới nhặt vô ích
    local function alreadyHolding(name)
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local ch = LocalPlayer.Character
        return (bp ~= nil and bp:FindFirstChild(name) ~= nil)
            or (ch ~= nil and ch:FindFirstChild(name) ~= nil)
    end

    -- Trái gần nhất còn nhặt được
    local function findNearestFruit(hrp)
        local bestObj, bestHandle, bestDist
        local maxDist = tonumber(_G.FruitPickupMaxDistance) or math.huge

        for _, obj in ipairs(workspace:GetChildren()) do
            if (obj:IsA("Tool") or obj:IsA("Model"))
                and string.find(string.lower(obj.Name), "fruit", 1, true)
                and not Players:GetPlayerFromCharacter(obj) then

                local ban = blacklist[obj]
                if not (ban and tick() < ban) and not alreadyHolding(obj.Name) then
                    local handle = obj:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        local d = (handle.Position - hrp.Position).Magnitude
                        if d <= maxDist and (not bestDist or d < bestDist) then
                            bestObj, bestHandle, bestDist = obj, handle, d
                        end
                    end
                end
            end
        end
        return bestObj, bestHandle
    end

    local FLY_SPEED = function() return tonumber(_G.FruitFlySpeed) or 300 end

    local function pickupFruit(fruit, handle)
        local function stillWanted()
            if not (_G.AutoPickupFruit and fruit.Parent == workspace and handle.Parent ~= nil) then return false end
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            return hum ~= nil and hum.Health > 0
        end

        -- Sea 2: quả rơi ở trong/ngoài Thuyền Ma sẽ đi qua cùng bộ điều phối;
        -- trả về trạng thái TRANSIT để vòng nhặt không tính nhầm là lần nhặt thất bại.
        do
            local rootForTransit = getRoot()
            if World2 and rootForTransit and Q.enterIfNeeded(rootForTransit, handle.Position, "fruit") then
                fruitLog("Đang chuyển qua cổng Thuyền Ma; sẽ thử nhặt lại sau khi tới nơi")
                return false, "TRANSIT"
            end
        end

        -- 0) SEA 1: đang ở đảo dưới nước (Underwater City) mà trái nằm ở ngoài -> bay tới điểm thoát để ra ngoài trước.
        --    (bay thẳng ~57000 studs qua hư không sẽ không tới được / chết)
        do
            local r0 = getRoot()
            if World1 and r0 and r0.Position.X > 50000 and handle.Position.X < 50000 then
                local ex = Q.UNDERWATER_FRUIT_EXIT
                fruitLog("Đang ở đảo dưới nước (Sea 1) -> bay tới điểm thoát", ex)
                _G.FlyStraight(function() return ex end, FLY_SPEED(), stillWanted, 3)

                local t0, lastTouch = tick(), 0
                while stillWanted() and tick() - t0 < Q.PORTAL_WAIT + 12 do
                    local root = getRoot()
                    if not root or root.Position.X < 50000 then break end   -- đã ra ngoài
                    root.CFrame = CFrame.new(ex)
                    root.AssemblyLinearVelocity  = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    if typeof(firetouchinterest) == "function" and tick() - lastTouch > 1 and tick() - t0 >= Q.PORTAL_WAIT then
                        lastTouch = tick()
                        local map = workspace:FindFirstChild("Map")
                        if map then
                            for _, d in ipairs(map:GetDescendants()) do
                                if d:IsA("BasePart") and (d.Position - ex).Magnitude <= 80 then
                                    local n = string.lower(d.Name)
                                    if string.find(n, "whirlpool", 1, true) or string.find(n, "portal", 1, true)
                                        or string.find(n, "exit", 1, true) or string.find(n, "gate", 1, true)
                                        or string.find(n, "teleport", 1, true) then
                                        pcall(function() firetouchinterest(root, d, 0); firetouchinterest(root, d, 1) end)
                                    end
                                end
                            end
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
                local r1 = getRoot()
                if not r1 or r1.Position.X > 50000 then
                    fruitLog("Chưa ra khỏi đảo dưới nước được")
                    return false
                end
                fruitLog("Đã ra khỏi đảo dưới nước -> bay đi nhặt trái")
            end
        end

        -- 0b) SEA 1: trái nằm ở ĐẢO DƯỚI NƯỚC (Underwater City) mà mình đang ở ngoài -> bay tới cổng vào (xoáy nước),
        --     gọi requestEntrance để xuống thành phố rồi mới bay đi nhặt trái.
        do
            local r0 = getRoot()
            if World1 and r0 and r0.Position.X < 50000 and handle.Position.X > 50000 then
                local gate = Q.getGate()
                fruitLog("Trái ở đảo dưới nước (Sea 1) -> bay tới cổng vào", gate)
                _G.FlyStraight(function() return gate end, FLY_SPEED(), stillWanted, 6)

                local entrance = Vector3.new(61163.8515625, 5.342342376708252, 1819.7841796875)
                local t0, lastReq = tick(), 0
                while stillWanted() and tick() - t0 < Q.PORTAL_WAIT + 20 do
                    local root = getRoot()
                    if not root or root.Position.X > 50000 then break end   -- đã xuống được dưới nước
                    gate = Q.getGate()
                    root.CFrame = CFrame.new(gate + Vector3.new(0, 2, 0))
                    root.AssemblyLinearVelocity  = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    if tick() - lastReq > 3 and tick() - t0 >= Q.PORTAL_WAIT then
                        lastReq = tick()
                        local _, part = Q.getGate()
                        if part and typeof(firetouchinterest) == "function" then
                            pcall(function() firetouchinterest(root, part, 0); firetouchinterest(root, part, 1) end)
                        end
                        local commF = getCommF()
                        if commF then
                            pcall(function() commF:InvokeServer("requestEntrance", entrance) end)
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
                local r1 = getRoot()
                if not r1 or r1.Position.X < 50000 then
                    fruitLog("Chưa xuống được đảo dưới nước")
                    return false
                end
                fruitLog("Đã xuống đảo dưới nước -> bay đi nhặt trái")
            end
        end

        -- 1) Bay THẲNG tới trái (bám theo vị trí hiện tại của Handle, không đi vòng, không tween)
        fruitLog("Bay thẳng tới", fruit.Name)
        local arrived = _G.FlyStraight(function()
            return handle.Parent and handle.Position or nil
        end, FLY_SPEED(), stillWanted, 2)
        if fruit.Parent ~= workspace then return true end -- đã bị nhặt/biến mất trong lúc bay
        if not arrived then return false end

        -- 2) Đứng đè lên Handle (mỗi frame) tới khi trái vào Backpack
        local t0 = tick()
        while stillWanted() and tick() - t0 < 3 do
            local root = getRoot()
            if not root then break end
            root.CFrame = CFrame.new(handle.Position)
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            if typeof(firetouchinterest) == "function" then
                pcall(function()
                    firetouchinterest(root, handle, 0)
                    firetouchinterest(root, handle, 1)
                end)
            end
            RunService.Heartbeat:Wait()
        end
        return fruit.Parent ~= workspace
    end

    while task.wait(0.5) do
        if _G.AutoPickupFruit then
            -- Raid / mua võ có ưu tiên cao hơn; trái có thể giành quyền từ farm thường.
            -- Nếu cờ FruitPickupBusy do luồng mua Random Fruit đặt, không chạy lượt nhặt thứ hai.
            local raidBusy = not Q.SmartController.canRun("fruit")
            if not raidBusy and _G.FruitPickupBusy ~= true then
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildOfClass("Humanoid")

                if hrp and hum and hum.Health > 0 then
                    local fruit, handle = findNearestFruit(hrp)
                    if fruit then
                        _G.FruitPickupBusy = true
                        fruitLog("Thấy trái:", fruit.Name)

                        local okCall, picked, pickupState = pcall(pickupFruit, fruit, handle)
                        _G.FruitPickupBusy = false -- luôn nhả cờ, kể cả khi lỗi

                        -- Noclip tắt: trả lại va chạm cho nhân vật
                        pcall(function()
                            local c = LocalPlayer.Character
                            if c then
                                for _, part in ipairs(c:GetChildren()) do
                                    if part:IsA("BasePart") then part.CanCollide = true end
                                end
                            end
                        end)

                        if okCall and picked then
                            attempts[fruit] = nil
                            fruitLog("✅ Đã nhặt:", fruit.Name)
                        elseif _G.AutoPickupFruit then
                            if pickupState == "TRANSIT" then
                                -- Đang qua cổng: không tăng bộ đếm lỗi/blacklist trái.
                                task.wait(0.1)
                            else
                                -- Chưa nhặt được sau 3 lần -> bỏ qua trái này 60 giây
                                attempts[fruit] = (attempts[fruit] or 0) + 1
                                if attempts[fruit] >= 3 then
                                    blacklist[fruit] = tick() + 60
                                    attempts[fruit] = nil
                                    fruitLog("⚠️ Bỏ qua tạm thời:", fruit.Name)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)


_G.MinhHubLoad(54, "Đang tải tab ESP...")
-- =========================================================
--   TAB ESP: PLAYER / TRÁI ÁC QUỶ / ĐẢO (SEA 1-2-3) / BERRY
-- =========================================================
-- Vẽ nhãn 2D bằng WorldToViewportPoint nên hiện được cả đảo ở rất xa, không phụ thuộc streaming.
-- Bọc trong hàm riêng (IIFE): chunk chính đã sát giới hạn 200 local, hàm mới có bộ đếm local riêng.
;(function()
    local CollectionService = game:GetService("CollectionService")
    local Camera = workspace.CurrentCamera

    _G.ESP_Player    = false
    _G.ESP_Fruit     = false
    _G.ESP_Island    = false
    _G.ESP_Highlight = true   -- viền màu (Highlight) cho Player & Trái
    _G.ESP_MaxDist   = math.huge

    -- Đảo theo từng Sea. Toạ độ ghi theo trí nhớ -> chỉ mang tính tương đối (đủ để định hướng).
    -- Nếu trong workspace._WorldOrigin.Locations có đảo cùng tên thì script dùng vị trí thật đó.
    local ESP_ISLANDS = {
        [1] = {
            {"Windmill",         Vector3.new(979.8, 16.5, 1429.0)},
            {"Marine Starter",   Vector3.new(-2566.4, 6.9, 2045.3)},
            {"Middle Town",      Vector3.new(-690.3, 15.1, 1582.2)},
            {"Jungle",           Vector3.new(-1612.8, 37.0, 149.1)},
            {"Pirate Village",   Vector3.new(-1181.3, 4.8, 3803.5)},
            {"Desert",           Vector3.new(944.2, 20.9, 4373.3)},
            {"Snow Island",      Vector3.new(1347.8, 104.7, -1319.7)},
            {"MarineFord",       Vector3.new(-4914.8, 51.0, 4281.0)},
            {"Colosseum",        Vector3.new(-1427.6, 7.3, -2792.8)},
            {"Sky Island 1",     Vector3.new(-4869.1, 733.5, -2667.0)},
            {"Sky Island 2",     Vector3.new(-4607.8, 872.5, -1667.6)},
            {"Sky Island 3",     Vector3.new(-7894.6, 5547.1, -380.3)},
            {"Prison",           Vector3.new(4875.3, 5.7, 734.9)},
            {"Magma Village",    Vector3.new(-5247.7, 12.9, 8505.0)},
            {"Underwater City",  Vector3.new(61163.9, 11.7, 1819.8)},
            {"Fountain City",    Vector3.new(5127.1, 59.5, 4105.4)},
        },
        [2] = {
            {"Cafe",             Vector3.new(-379.6, 73.0, 297.4)},
            {"Factory",          Vector3.new(295.0, 73.0, -56.0)},
            {"Green Zone",       Vector3.new(-2448.5, 73.0, -3210.6)},
            {"Graveyard",        Vector3.new(-5622.0, 492.2, -778.9)},
            {"Snow Mountain",    Vector3.new(753.1, 408.2, -5274.6)},
            {"Hot and Cold",     Vector3.new(-6127.6, 15.9, -5040.3)},
            {"Cursed Ship",      Vector3.new(923.2, 125.1, 32885.9)},
            {"Ice Castle",       Vector3.new(6148.4, 294.4, -6741.1)},
            {"Forgotten Island", Vector3.new(-3032.2, 317.9, -10075.4)},
            {"Usoap Island",     Vector3.new(4816.3, 8.5, 2863.2)},
            {"Mansion",          Vector3.new(2286.0, 15.0, 863.0)},
            {"Raid Room",        Vector3.new(-6438.7, 250.6, -4501.5)},
        },
        [3] = {
            {"Port Town",        Vector3.new(-290.0, 43.0, 5583.0)},
            {"Hydra Island",     Vector3.new(5228.9, 603.9, 345.0)},
            {"Great Tree",       Vector3.new(2681.3, 1682.8, -7190.0)},
            {"Floating Turtle",  Vector3.new(-13274.5, 531.8, -7579.2)},
            {"Deep Forest",      Vector3.new(-10919.3, 331.8, -8637.6)},
            {"Haunted Castle",   HAUNTED_CASTLE_POS},
            {"Castle on the Sea",Vector3.new(-5017.4, 314.8, -2823.0)},
            {"Cake Island",      CAKE_ISLAND_POS},
            {"Peanut Island",    Vector3.new(-2062.7, 50.5, -10232.6)},
            {"Ice Cream Island", Vector3.new(-902.6, 79.9, -10988.8)},
            {"Tiki Outpost",     Vector3.new(-16269.7, 25.2, 1373.7)},
            {"Submerged Island", SUBMERGED_CENTER},
        },
    }

    -- Đảo xuất hiện theo sự kiện (Sea 3): đọc trực tiếp từ workspace, có thì mới hiện
    local DYNAMIC_ISLANDS = {
        {"Mirage Island",     {"MysticIsland", "Mirage Island"}},
        {"Prehistoric Island",{"PrehistoricIsland", "Prehistoric Island"}},
        {"Kitsune Island",    {"KitsuneIsland", "Kitsune Island"}},
    }

    local seaIdx = World1 and 1 or (World2 and 2 or 3)

    -- ===== UI overlay riêng =====
    local espGui = Instance.new("ScreenGui")
    espGui.Name = "MinhHubESP"
    espGui.ResetOnSpawn = false
    espGui.IgnoreGuiInset = true
    espGui.DisplayOrder = 999990 -- thấp hơn menu chính để menu luôn nằm trên
    espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        if syn and type(syn) == "table" and syn.protect_gui then syn.protect_gui(espGui) end
    end)
    pcall(function()
        local old = uiContainer:FindFirstChild("MinhHubESP")
        if old then old:Destroy() end
    end)
    espGui.Parent = uiContainer

    local hlFolder = Instance.new("Folder")
    hlFolder.Name = "MinhHubESP_Highlights"
    hlFolder.Parent = uiContainer

    local COLORS = {
        Pirates = Color3.fromRGB(255, 80, 80),
        Marines = Color3.fromRGB(80, 150, 255),
        Player  = Color3.fromRGB(255, 255, 255),
        Fruit   = Color3.fromRGB(255, 120, 255),
        Island  = Color3.fromRGB(90, 230, 255),
        Event   = Color3.fromRGB(255, 200, 60),
        Berry   = Color3.fromRGB(120, 255, 120),
    }

    -- entries[kind][key] = {label=TextLabel, hl=Highlight|nil, getPos=fn, text=string, color=Color3}
    local entries = { Player = {}, Fruit = {}, Island = {}, Berry = {} }
    local counts  = { Player = 0, Fruit = 0, Island = 0, Berry = 0 }

    local function makeLabel(color)
        local l = Instance.new("TextLabel")
        l.AnchorPoint = Vector2.new(0.5, 1)
        l.AutomaticSize = Enum.AutomaticSize.XY
        l.Size = UDim2.new(0, 0, 0, 0)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = 13
        l.TextColor3 = color
        l.TextStrokeTransparency = 0.25
        l.TextStrokeColor3 = Color3.new(0, 0, 0)
        l.Visible = false
        l.Parent = espGui
        return l
    end

    local function removeEntry(kind, key)
        local e = entries[kind][key]
        if not e then return end
        if e.label then e.label:Destroy() end
        if e.hl then e.hl:Destroy() end
        entries[kind][key] = nil
    end

    local function clearKind(kind)
        for key in pairs(entries[kind]) do removeEntry(kind, key) end
        counts[kind] = 0
    end

    -- Tạo / cập nhật 1 mục ESP
    local function upsert(kind, key, getPos, text, color, adorneeForHL)
        local e = entries[kind][key]
        if not e then
            e = { label = makeLabel(color), getPos = getPos }
            entries[kind][key] = e
        end
        e.getPos = getPos
        e.text   = text
        e.color  = color
        e.label.TextColor3 = color

        local wantHL = _G.ESP_Highlight and adorneeForHL ~= nil
        if wantHL and not e.hl then
            local hl = Instance.new("Highlight")
            hl.FillTransparency = 0.75
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = hlFolder
            e.hl = hl
        elseif not wantHL and e.hl then
            e.hl:Destroy(); e.hl = nil
        end
        if e.hl then
            e.hl.Adornee = adorneeForHL
            e.hl.FillColor = color
            e.hl.OutlineColor = color
        end
    end

    local function myPos()
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        return r and r.Position
    end

    -- ===== Thu thập dữ liệu (chạy mỗi 0.5s, không chạy mỗi frame) =====
    local function collectPlayers()
        local seen = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if head and hum and hum.Health > 0 then
                    seen[plr] = true
                    local lvl = ""
                    pcall(function()
                        local d = plr:FindFirstChild("Data")
                        if d and d:FindFirstChild("Level") then lvl = " [Lv." .. tostring(d.Level.Value) .. "]" end
                    end)
                    local color = COLORS.Player
                    pcall(function()
                        if plr.Team and COLORS[plr.Team.Name] then color = COLORS[plr.Team.Name] end
                    end)
                    local hp = math.floor(hum.Health / math.max(hum.MaxHealth, 1) * 100)
                    upsert("Player", plr,
                        function() return head.Position + Vector3.new(0, 2.5, 0) end,
                        plr.DisplayName .. lvl .. "  " .. hp .. "% HP", color, char)
                end
            end
        end
        for plr in pairs(entries.Player) do
            if not seen[plr] then removeEntry("Player", plr) end
        end
    end

    local function collectFruits()
        local seen = {}
        for _, obj in ipairs(workspace:GetChildren()) do
            if (obj:IsA("Tool") or obj:IsA("Model"))
                and string.find(string.lower(obj.Name), "fruit", 1, true)
                and not Players:GetPlayerFromCharacter(obj) then
                local handle = obj:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    seen[obj] = true
                    upsert("Fruit", obj,
                        function() return handle.Position + Vector3.new(0, 3, 0) end,
                        "🍎 " .. obj.Name, COLORS.Fruit, obj)
                end
            end
        end
        for obj in pairs(entries.Fruit) do
            if not seen[obj] or not obj.Parent then removeEntry("Fruit", obj) end
        end
    end

    local function collectIslands()
        local seen = {}
        local locations = workspace:FindFirstChild("_WorldOrigin")
            and workspace._WorldOrigin:FindFirstChild("Locations")

        for _, info in ipairs(ESP_ISLANDS[seaIdx] or {}) do
            local name, pos = info[1], info[2]
            -- ưu tiên vị trí thật nếu có đảo cùng tên trong Locations
            local live = locations and locations:FindFirstChild(name)
            if live then
                local okPv, cf = pcall(function() return live:GetPivot() end)
                if okPv and cf then pos = cf.Position end
            end
            seen[name] = true
            upsert("Island", name, function() return pos + Vector3.new(0, 40, 0) end,
                "🏝 " .. name, COLORS.Island, nil)
        end

        -- đảo sự kiện (chỉ hiện khi đang tồn tại)
        for _, info in ipairs(DYNAMIC_ISLANDS) do
            local label, names = info[1], info[2]
            local found
            for _, nm in ipairs(names) do
                found = (locations and locations:FindFirstChild(nm))
                    or (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild(nm))
                if found then break end
            end
            if found then
                seen[label] = true
                upsert("Island", label, function()
                    local okPv, cf = pcall(function() return found:GetPivot() end)
                    return (okPv and cf and cf.Position or Vector3.zero) + Vector3.new(0, 80, 0)
                end, "⭐ " .. label, COLORS.Event, nil)
            end
        end

        for name in pairs(entries.Island) do
            if not seen[name] then removeEntry("Island", name) end
        end
    end


    local collectors = {
        { "Player", "ESP_Player", collectPlayers },
        { "Fruit",  "ESP_Fruit",  collectFruits  },
        { "Island", "ESP_Island", collectIslands },
    }

    _G.MHSpawn(function()
        while task.wait(0.5) do
            for _, c in ipairs(collectors) do
                local kind, flag, fn = c[1], c[2], c[3]
                if _G[flag] then
                    pcall(fn)
                elseif next(entries[kind]) then
                    clearKind(kind) -- tắt ESP: xoá sạch nhãn & viền
                end
                local n = 0
                for _ in pairs(entries[kind]) do n = n + 1 end
                counts[kind] = n
            end
        end
    end)

    -- ===== Vẽ nhãn mỗi frame =====
    RunService.RenderStepped:Connect(function()
        Camera = workspace.CurrentCamera or Camera
        if not Camera then return end
        if not (_G.ESP_Player or _G.ESP_Fruit or _G.ESP_Island) then return end -- tắt hết ESP: không tốn CPU
        local me = myPos()
        local maxD = tonumber(_G.ESP_MaxDist) or math.huge

        for _, bucket in pairs(entries) do
            for _, e in pairs(bucket) do
                local okPos, pos = pcall(e.getPos)
                if okPos and pos then
                    local screen, onScreen = Camera:WorldToViewportPoint(pos)
                    local dist = me and (pos - me).Magnitude or (pos - Camera.CFrame.Position).Magnitude
                    if onScreen and screen.Z > 0 and dist <= maxD then
                        e.label.Position = UDim2.fromOffset(screen.X, screen.Y)
                        local dm = math.floor(dist)
                        if e._lt ~= e.text or e._ld ~= dm then   -- chỉ cập nhật chữ khi đổi (đỡ tạo chuỗi mỗi frame)
                            e._lt, e._ld = e.text, dm
                            e.label.Text = string.format("%s\n[%d m]", e.text, dm)
                        end
                        if not e.label.Visible then e.label.Visible = true end
                    elseif e.label.Visible then
                        e.label.Visible = false
                    end
                elseif e.label.Visible then
                    e.label.Visible = false
                end
            end
        end
    end)

    -- ===== TAB ESP trong menu =====
    local espPage = createTab("ESP", "👁️", false)
    -- đưa tab ESP lên trước tab Config trong sidebar
    pcall(function()
        tabs["ESP"].Button.LayoutOrder = 1
        if tabs["Config"] then tabs["Config"].Button.LayoutOrder = 2 end
    end)

    createToggleFeature(espPage, "ESPPlayerToggle", "ESP Player", "Show other players’ names, level, health, and distance (red: Pirates, blue: Marines)", 1, _G.ESP_Player, function(state)
        _G.ESP_Player = state
    end)
    createToggleFeature(espPage, "ESPFruitToggle", "ESP Fruit", "Show the names and distances of dropped Devil Fruits", 2, _G.ESP_Fruit, function(state)
        _G.ESP_Fruit = state
    end)
    createToggleFeature(espPage, "ESPIslandToggle", "ESP Island (Sea " .. seaIdx .. ")", "Show names and distances of islands in the current Sea, including event islands", 3, _G.ESP_Island, function(state)
        _G.ESP_Island = state
    end)
    createToggleFeature(espPage, "ESPHighlightToggle", "ESP Highlight", "Show through-wall highlights for players and fruits (disable if performance drops)", 5, _G.ESP_Highlight, function(state)
        _G.ESP_Highlight = state
        for _, kind in ipairs({"Player", "Fruit"}) do
            for _, e in pairs(entries[kind]) do
                if not state and e.hl then e.hl:Destroy(); e.hl = nil end
            end
        end
    end)

    -- Thẻ thống kê số lượng đang hiển thị
    local statCard = Instance.new("Frame")
    statCard.Size = UDim2.new(1, 0, 0, 34)
    statCard.BackgroundColor3 = BANANA_CARD
    statCard.LayoutOrder = 6
    statCard.Parent = espPage
    addCorner(statCard, 8)
    addStroke(statCard, BANANA_CARD_BORDER, 1)

    local statText = Instance.new("TextLabel")
    statText.Size = UDim2.new(1, -24, 1, 0)
    statText.Position = UDim2.new(0, 12, 0, 0)
    statText.BackgroundTransparency = 1
    statText.TextColor3 = Color3.fromRGB(190, 190, 200)
    statText.TextSize = 11
    statText.Font = Enum.Font.Gotham
    statText.TextXAlignment = Enum.TextXAlignment.Left
    statText.Parent = statCard

    _G.MHSpawn(function()
        while statText.Parent do
            statText.Text = string.format("👁 Player: %d  |  Fruits: %d  |  Islands: %d",
                counts.Player, counts.Fruit, counts.Island)
            task.wait(0.5)
        end
    end)
end)()

-- LOGIC AUTO RANDOM BONES & STORE FRUIT
-- Có cooldown giữa các lần đổi Bones để tránh spam remote; server vẫn tự xác thực số Bones cần thiết.
_G.MHSpawn(function()
    local nextBonesBuyAt = 0
    while task.wait(1) do
        if autoRandomBonesEnabled and tick() >= nextBonesBuyAt then
            nextBonesBuyAt = tick() + 8
            local okBuy = pcall(function()
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local commF = remotes and remotes:FindFirstChild("CommF_")
                if commF then commF:InvokeServer("Bones", "Buy", 1, 1) end
            end)
            if not okBuy then nextBonesBuyAt = tick() + 15 end
        end
    end
end)

-- LOGIC AUTO STORE FRUIT v2
-- Sửa lỗi: server nhận tên "gốc" của trái (thuộc tính OriginalName) chứ không phải Tool.Name, nên bản cũ gọi
-- StoreFruit bằng tên sai và không bao giờ cất được. Giờ thử lần lượt các tên có thể, kiểm tra trái đã biến mất
-- khỏi người chơi chưa; nếu remote vẫn không được thì làm như ảnh hướng dẫn: cầm trái -> bấm "Store" trong hộp thoại.
_G.StoreFruitStatus = "Disabled"
_G.MHSpawn(function()
    local failCount = setmetatable({}, {__mode = "k"})  -- số vòng thất bại mỗi Tool
    local skipUntil = setmetatable({}, {__mode = "k"})  -- bỏ qua tạm thời Tool không cất được

    local function setStatus(t)
        if _G.StoreFruitStatus ~= t then
            _G.StoreFruitStatus = t
            print("[StoreFruit]", t)
        end
    end

    local function stillOwned(tool)
        local char = LocalPlayer.Character
        local bp = LocalPlayer:FindFirstChild("Backpack")
        return tool.Parent ~= nil and ((bp and tool:IsDescendantOf(bp)) or (char and tool:IsDescendantOf(char)))
    end

    local function guiVisible(obj, pg)
        local g = obj
        while g and g ~= pg do
            if g:IsA("GuiObject") and not g.Visible then return false end
            if g:IsA("ScreenGui") and not g.Enabled then return false end
            g = g.Parent
        end
        return true
    end

    -- Cách dự phòng: cầm trái, click để hiện hộp thoại Eat/Drop/Store/Nevermind rồi bấm đúng nút "Store"
    local function storeViaDialog(tool)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not hum or not pg then return false end

        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.35)
        pcall(function() tool:Activate() end)

        local deadline = tick() + 3
        while tick() < deadline and stillOwned(tool) do
            local storeBtn
            for _, d in ipairs(pg:GetDescendants()) do
                if (d:IsA("TextButton") or d:IsA("ImageButton")) and guiVisible(d, pg) then
                    local t = ""
                    pcall(function()
                        if d:IsA("TextButton") then t = d.Text end
                        for _, c in ipairs(d:GetDescendants()) do
                            if c:IsA("TextLabel") or c:IsA("TextButton") then t = t .. " " .. c.Text end
                        end
                    end)
                    if string.lower(t):match("^%s*store%s*$") then storeBtn = d; break end
                end
            end

            if storeBtn then
                pcall(function()
                    local vim = game:GetService("VirtualInputManager")
                    local inset = game:GetService("GuiService"):GetGuiInset()
                    local pos = storeBtn.AbsolutePosition + storeBtn.AbsoluteSize / 2
                    vim:SendMouseButtonEvent(pos.X, pos.Y + inset.Y, 0, true, game, 0)
                    task.wait(0.05)
                    vim:SendMouseButtonEvent(pos.X, pos.Y + inset.Y, 0, false, game, 0)
                end)
                task.wait(0.6)
                break
            end
            task.wait(0.3)
        end
        return not stillOwned(tool)
    end

    local function storeTool(commF, tool)
        local until_ = skipUntil[tool]
        if until_ and tick() < until_ then return end

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        -- Bỏ trái đang cầm về Backpack trước
        if char and tool.Parent == char and hum then
            pcall(function() hum:UnequipTools() end)
            task.wait(0.2)
        end

        -- Các tên khả dĩ mà server chấp nhận (không trùng nhau)
        local candidates, seen = {}, {}
        local function add(n)
            if type(n) == "string" and n ~= "" and not seen[n] then
                seen[n] = true
                candidates[#candidates + 1] = n
            end
        end
        add(tool:GetAttribute("OriginalName"))
        add(tool:GetAttribute("FruitName"))
        add(tool.Name)
        add((string.gsub(tool.Name, " Fruit$", "")))

        local lastResult = nil
        for _, nm in ipairs(candidates) do
            local ok, res = pcall(function() return commF:InvokeServer("StoreFruit", nm, tool) end)
            lastResult = ok and res or ("lỗi: " .. tostring(res))
            task.wait(0.4)
            if not stillOwned(tool) then
                setStatus("✅ Đã cất: " .. tool.Name .. " (tên gửi: " .. nm .. ")")
                failCount[tool] = nil
                return
            end
        end

        failCount[tool] = (failCount[tool] or 0) + 1
        local reason = (type(lastResult) == "string" and lastResult) or (lastResult ~= nil and tostring(lastResult)) or "không rõ"
        setStatus("⚠️ Remote không cất được " .. tool.Name .. " (server trả: " .. reason .. ")")

        -- Remote thất bại 2 vòng liên tiếp -> dùng hộp thoại Store
        if failCount[tool] >= 2 then
            if storeViaDialog(tool) then
                setStatus("✅ Đã cất bằng hộp thoại: " .. tool.Name)
                failCount[tool] = nil
            elseif failCount[tool] >= 4 then
                skipUntil[tool] = tick() + 60
                failCount[tool] = nil
                setStatus("❌ Không cất được " .. tool.Name .. " - kho đầy? Bỏ qua 60 giây")
            end
        end
    end

    while task.wait(1) do
        if autoStoreFruitEnabled then
            pcall(function()
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local commF = remotes and remotes:FindFirstChild("CommF_")
                if not commF then setStatus("Không thấy Remotes.CommF_"); return end

                -- Không cất trái khi đang bay đi nhặt / đang mua ở NPC
                if _G.FruitPickupBusy then return end

                local list = {}
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                local char = LocalPlayer.Character
                if backpack then for _, t in ipairs(backpack:GetChildren()) do list[#list + 1] = t end end
                if char then for _, t in ipairs(char:GetChildren()) do list[#list + 1] = t end end

                local found = false
                for _, tool in ipairs(list) do
                    if _G.IsFruitTool and _G.IsFruitTool(tool) and tool.Parent then
                        found = true
                        storeTool(commF, tool)
                    end
                end
                if not found then setStatus("Chờ trái ác quỷ trong Backpack...") end
            end)
        else
            _G.StoreFruitStatus = "Disabled"
        end
    end
end)

-- HÀM PHÂN LOẠI VŨ KHÍ: ƯU TIÊN TOOLTIP/ATTRIBUTE, KHÔNG TỰ CHỌN TOOL KHÁC LOẠI
local function isMatchingWeaponType(tool, targetType)
    if not tool or not tool:IsA("Tool") then return false end
    local target = string.lower(tostring(targetType or "Melee"))
    local name = string.lower(tool.Name)

    -- Tool.ToolTip là thuộc tính Roblox; một số bản script/game cũng dùng Attribute/StringValue.
    local tip = ""
    pcall(function() tip = string.lower(tostring(tool.ToolTip or "")) end)
    local attr = tool:GetAttribute("ToolTipType") or tool:GetAttribute("Type")
    if attr ~= nil then tip = string.lower(tostring(attr)) end
    local value = tool:FindFirstChild("ToolTipType")
    if value and value:IsA("StringValue") then tip = string.lower(value.Value) end

    if target == "melee" then
        if tip == "melee" then return true end
        local keys = {"combat", "black leg", "electro", "fishman karate", "dragon claw", "superhuman", "death step", "sharkman karate", "electric claw", "dragon talon", "godhuman", "sanguine art"}
        for _, key in ipairs(keys) do if string.find(name, key, 1, true) then return true end end
        return false
    elseif target == "sword" then
        if tip == "sword" then return true end
        -- Tên chỉ là fallback khi server không cung cấp ToolTip rõ ràng.
        local keys = {"katana", "saber", "cutlass", "sword", "yoru", "pole", "pipe", "trident", "scythe", "dagger", "bisento", "soul cane", "fox lamp", "cursed dual", "true triple", "hallow", "warden", "tushita", "yama", "shisui", "spikey trident", "dark blade"}
        for _, key in ipairs(keys) do if string.find(name, key, 1, true) then return true end end
        return false
    elseif target == "blox fruit" or target == "fruit" then
        if tip == "blox fruit" or tip == "fruit" then return true end
        -- FIX: Tool trái luôn có dấu gạch ngang (Dragon-Dragon, Leopard-Leopard...) hoặc có Fruit/OriginalName
        if tool:FindFirstChild("Fruit") ~= nil or tool:GetAttribute("Fruit") ~= nil or tool:GetAttribute("OriginalName") ~= nil then return true end
        if tip ~= "" and tip ~= "blox fruit" then return false end   -- đã có ToolTip khác (Melee/Sword/Gun) -> chắc chắn không phải trái
        if string.find(name, "%-") or string.find(name, "fruit", 1, true) then return true end
        local keys = {"rocket", "spin", "chop", "spring", "bomb", "smoke", "spike", "flame", "falcon", "ice", "sand", "dark", "diamond", "light", "rubber", "barrier", "ghost", "magma", "quake", "buddha", "love", "spider", "sound", "phoenix", "portal", "rumble", "pain", "blizzard", "gravity", "mammoth", "t-rex", "dough", "shadow", "venom", "control", "gas", "spirit", "dragon", "tiger", "kitsune", "yeti"}
        for _, key in ipairs(keys) do if string.find(name, key, 1, true) then return true end end
        return false
    elseif target == "gun" then
        if tip == "gun" then return true end
        -- Tool súng có remote bắn riêng
        if tool:FindFirstChild("RemoteFunctionShoot") or tool:FindFirstChild("RemoteEventShootGun") then return true end
        if tip ~= "" then return false end   -- đã có ToolTip khác -> không phải súng
        local keys = {"flintlock", "musket", "slingshot", "bazooka", "cannon", "rifle", "blaster", "kabucha", "dragonstorm", "guitar", "bow", "acidum", "hellfire", "revolver", "pistol"}
        for _, key in ipairs(keys) do if string.find(name, key, 1, true) then return true end end
        return false
    end
    return false
end
_G.MHIsWeaponType = isMatchingWeaponType

local function equipSelectedWeapon(weaponName)
    -- Menu là nguồn chính; đồng bộ _G để các module farm cùng dùng một lựa chọn.
    local targetW = tostring(weaponName or selectedWeapon or _G.SelectWeapon or "Melee")
    if targetW ~= "Melee" and targetW ~= "Sword" and targetW ~= "Blox Fruit" and targetW ~= "Gun" then targetW = "Melee" end
    selectedWeapon, _G.SelectWeapon = targetW, targetW

    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not backpack or not humanoid or humanoid.Health <= 0 then return false end

    -- Súng cụ thể do người dùng chọn trong danh sách (rỗng = tự chọn súng bất kỳ)
    local wantName = nil
    if targetW == "Gun" and type(_G.SelectGun) == "string" and _G.SelectGun ~= "" then wantName = _G.SelectGun end

    local currentTool = character:FindFirstChildOfClass("Tool")
    if currentTool and isMatchingWeaponType(currentTool, targetW) and (not wantName or currentTool.Name == wantName) then return true end

    -- Tìm chính xác trong balo. Không còn fallback trang bị Tool bất kỳ, nguyên nhân chính gây chọn sai.
    for pass = 1, 2 do
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and isMatchingWeaponType(tool, targetW) and (not wantName or tool.Name == wantName) then
                pcall(function() humanoid:EquipTool(tool) end)
                task.wait(0.1)
                local equipped = character:FindFirstChildOfClass("Tool")
                if equipped == tool then return true end
                -- FIX: EquipTool không ăn (hay gặp với Trái Ác Quỷ) -> ép cầm trực tiếp
                pcall(function() tool.Parent = character end)
                task.wait(0.1)
                if character:FindFirstChildOfClass("Tool") == tool then return true end
            end
        end
        -- Không có súng đã chọn trong balo: nếu đang cầm 1 súng khác thì giữ, còn không thì lấy súng bất kỳ
        if not wantName then break end
        if currentTool and isMatchingWeaponType(currentTool, targetW) then return true end
        wantName = nil
    end
    warn("[Minh Hub] Không tìm thấy vũ khí đúng loại: " .. targetW .. ". Giữ nguyên trang bị hiện tại, không tự chọn nhầm.")
    return false
end
_G.EquipWeapon = equipSelectedWeapon

-- HỆ THỐNG FARM MATERIAL ĐA SEA (Sea 1 / 2 / 3)
-- Tìm quái theo TÊN trong workspace.Enemies, bay tới điểm hồi sinh (EnemySpawns) khi chưa có quái.
local MatFarm = {
    sea = World1 and 1 or (World2 and 2 or 3),
    cacheKey = nil,
    set = nil,
    points = nil,
    pointsAt = 0,
    locked = nil,
    warnKey = nil,
    lastEntrance = 0,
}

do
    local function notify(text)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Auto Farm Material",
                Text = text,
                Duration = 6,
            })
        end)
        print("[Material]", text)
    end

    -- Cố định khu farm Scrap Metal & Leather ở Sea 1: Pirate Village.
    -- Không lấy điểm spawn Pirate/Brute từ khu vực khác trên toàn map.
    local PIRATE_VILLAGE_MATERIAL_CENTER = Vector3.new(-1076.60, 27.30, 3960.73)
    local PIRATE_VILLAGE_MATERIAL_RADIUS = 900

    -- "Pirate [Lv. 35]" -> "Pirate"
    local function normalizeMobName(name)
        return (tostring(name):gsub("%s*%[.-%]%s*$", ""))
    end

    local function getPlayerRoot()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function partPosition(obj)
        if obj:IsA("BasePart") then
            return obj.Position
        end
        local ok, cf = pcall(function() return obj:GetPivot() end)
        return ok and cf and cf.Position or nil
    end

    local function seaListText(perSea)
        local list = {}
        for sea = 1, 3 do
            if perSea[sea] then
                list[#list + 1] = "Sea " .. sea
            end
        end
        return table.concat(list, ", ")
    end

    -- Trả về (tập tên quái, dữ liệu) của material đang chọn ở Sea hiện tại; nil nếu không farm được.
    function MatFarm.getMobSet()
        local sel = selectedMaterialTarget
        local data = materialData[sel]

        if not data then
            if MatFarm.warnKey ~= "none" then
                MatFarm.warnKey = "none"
                notify("No material selected in the menu.")
            end
            return nil
        end

        local entry = data[MatFarm.sea]
        if not entry then
            local key = sel .. "_noSea" .. MatFarm.sea
            if MatFarm.warnKey ~= key then
                MatFarm.warnKey = key
                notify(sel .. " không rớt ở Sea " .. MatFarm.sea .. ". Hãy qua: " .. seaListText(data))
            end
            return nil
        end

        local key = sel .. "_" .. MatFarm.sea
        if MatFarm.cacheKey ~= key then
            MatFarm.cacheKey = key
            MatFarm.warnKey = nil
            MatFarm.set = {}
            for _, mobName in ipairs(entry.mobs) do
                MatFarm.set[mobName] = true
            end
            MatFarm.points = nil
            MatFarm.pointsAt = 0
            MatFarm.locked = nil
        end

        return MatFarm.set, entry
    end

    local function isMatMob(enemy)
        return enemy ~= nil and MatFarm.set ~= nil and MatFarm.set[normalizeMobName(enemy.Name)] == true
    end

    local function isAlive(enemy)
        if not enemy or not enemy.Parent then return false end
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        return hum ~= nil and hum.Health > 0 and enemy:FindFirstChild("HumanoidRootPart") ~= nil
    end

    -- Với Scrap Metal & Leather ở Sea 1, chỉ nhận Pirate/Brute trong vùng Pirate Village.
    -- Phần kiểm tra khoảng cách ngang tránh đuổi theo mục tiêu ở đảo khác.
    local function isInsidePirateVillageMaterialArea(enemy)
        if MatFarm.sea ~= 1 or selectedMaterialTarget ~= "Scrap Metal & Leather" then
            return true
        end
        local root = enemy and enemy:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        local delta = root.Position - PIRATE_VILLAGE_MATERIAL_CENTER
        local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
        return horizontalDistance <= PIRATE_VILLAGE_MATERIAL_RADIUS
    end

    -- Quái rớt material gần người chơi nhất (giữ nguyên mục tiêu cũ khi còn sống để không đổi qua đổi lại).
    function MatFarm.getEnemy()
        local set = MatFarm.getMobSet()
        if not set then return nil end

        if MatFarm.locked and isAlive(MatFarm.locked) and isMatMob(MatFarm.locked)
            and isInsidePirateVillageMaterialArea(MatFarm.locked) then
            return MatFarm.locked
        end
        MatFarm.locked = nil

        local playerHrp = getPlayerRoot()
        if not playerHrp then return nil end

        local enemiesFolder = workspace:FindFirstChild("Enemies") or workspace
        local best, bestDist = nil, math.huge
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            if isMatMob(enemy) and isAlive(enemy) and isInsidePirateVillageMaterialArea(enemy) then
                local d = (enemy.HumanoidRootPart.Position - playerHrp.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = enemy
                end
            end
        end

        MatFarm.locked = best
        return best
    end

    -- Danh sách điểm đứng chờ quái hồi sinh (lấy từ EnemySpawns của chính Sea đang chơi).
    function MatFarm.getPoints()
        local set, entry = MatFarm.getMobSet()
        if not set then return {} end

        if MatFarm.points and (tick() - MatFarm.pointsAt) < 15 then
            return MatFarm.points
        end

        -- Scrap Metal & Leather ở Sea 1 chỉ dùng một điểm chờ tại Pirate Village.
        -- Tránh vòng lặp đổi giữa nhiều EnemySpawns khiến nhân vật bay khỏi hòn đảo.
        if MatFarm.sea == 1 and selectedMaterialTarget == "Scrap Metal & Leather" then
            MatFarm.points = {PIRATE_VILLAGE_MATERIAL_CENTER}
            MatFarm.pointsAt = tick()
            return MatFarm.points
        end

        local found = {}
        local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
        local spawns = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns")

        if spawns then
            for pass = 1, 2 do
                for _, sp in ipairs(spawns:GetChildren()) do
                    local match = set[normalizeMobName(sp.Name)] == true
                    if not match and pass == 2 then
                        local low = string.lower(sp.Name)
                        for mobName in pairs(set) do
                            if string.find(low, string.lower(mobName), 1, true) then
                                match = true
                                break
                            end
                        end
                    end
                    if match then
                        local pos = partPosition(sp)
                        if pos then found[#found + 1] = pos end
                    end
                end
                if #found > 0 then break end
            end
        end

        local points = {}
        if #found > 0 then
            local hrp = getPlayerRoot()
            local origin = hrp and hrp.Position or found[1]
            table.sort(found, function(a, b)
                return (a - origin).Magnitude < (b - origin).Magnitude
            end)

            -- Chỉ lấy cụm điểm gần nhất, bỏ điểm trùng nhau để vòng quét ngắn gọn.
            local nearest = found[1]
            for _, pos in ipairs(found) do
                if #points >= 10 then break end
                if (pos - nearest).Magnitude <= 700 then
                    local dup = false
                    for _, p in ipairs(points) do
                        if (p - pos).Magnitude < 60 then dup = true break end
                    end
                    if not dup then points[#points + 1] = pos end
                end
            end
        else
            for _, pos in ipairs(entry.spots) do
                points[#points + 1] = pos
            end
        end

        MatFarm.points = points
        MatFarm.pointsAt = tick()
        return points
    end

    -- Sea 1: Underwater City (Fish Tail) cần "requestEntrance" mới vào được.
    -- Trả về true nếu vừa dịch chuyển (vòng lặp nên chờ frame sau).
    function MatFarm.enterIfNeeded(hrp, targetPos)
        if not hrp or not targetPos then return false end

        -- Sea 2 material farming shares the same Cursed Ship entrance coordinator.
        if World2 then
            return Q.enterIfNeeded(hrp, targetPos, "material")
        end

        if MatFarm.sea == 1 and targetPos.X > 50000 and hrp.Position.X < 50000 then
            if Q.flyToFishmanGate(hrp) then return true end   -- bay tới cổng vào trước
            if tick() - MatFarm.lastEntrance > 6 then
                MatFarm.lastEntrance = tick()
                pcall(function()
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    local commF = remotes and remotes:FindFirstChild("CommF_")
                    if commF then
                        commF:InvokeServer("requestEntrance", Vector3.new(61163.8515625, 5.342342376708252, 1819.7841796875))
                    end
                end)
            end
            return true
        end
        return false
    end
end

local function getTargetEnemy()
    local closestEnemy, shortestDistance = nil, math.huge
    local character = LocalPlayer.Character

    if character and character:FindFirstChild("HumanoidRootPart") then
        local playerPos = character.HumanoidRootPart.Position
        local enemiesFolder = workspace:FindFirstChild("Enemies") or workspace

        -- NEARBY MOBS: đánh quái gần nhất quanh nhân vật, không nhận quest, không bay đi xa
        if selectedFarmTarget == "Nearby Mobs" then
            local nearest, nearestDist = nil, tonumber(_G.NearbyMobRadius) or 400
            for _, v in pairs(enemiesFolder:GetChildren()) do
                local nhrp, nhum = v:FindFirstChild("HumanoidRootPart"), v:FindFirstChildOfClass("Humanoid")
                if nhrp and nhum and nhum.Health > 0 then
                    local nd = (nhrp.Position - playerPos).Magnitude
                    if nd < nearestDist then nearestDist = nd; nearest = v end
                end
            end
            return nearest
        end

        -- Cake Prince: ưu tiên boss đang sống; trước khi boss xuất hiện, chọn quái Cake Land gần nhất.
        -- Quái đúng quest được cộng ưu tiên nhẹ, nhưng không khiến nhân vật bay xuyên đảo chỉ để đuổi một mục tiêu xa.
        if selectedFarmTarget == "Cake Prince" then
            -- Ưu tiên boss đang sống trước mọi quái thường; hỗ trợ model nằm sâu trong Enemies.
            local boss = Q.FindLiveCakeBoss()
            if boss then return boss end
            -- Khi cổng đã mở/đủ điều kiện gọi boss thì không quay lại farm quái thường.
            if isCakePrinceReady then return nil end

            local _, _, preferredName = Q.GetCakeQuestData()
            local preferred = string.lower(tostring(preferredName or ""))
            local bestMob, bestScore = nil, math.huge
            local cakeCenter = CAKE_ISLAND_POS
            for _, mob in ipairs(enemiesFolder:GetChildren()) do
                local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                local hum = mob:FindFirstChildOfClass("Humanoid")
                local name = string.lower(mob.Name)
                local isCakeLandMob = string.find(name, "cookie crafter", 1, true)
                    or string.find(name, "cake guard", 1, true)
                    or string.find(name, "baking staff", 1, true)
                    or string.find(name, "head baker", 1, true)
                if mobRoot and hum and hum.Health > 0 and isCakeLandMob
                    and (mobRoot.Position - cakeCenter).Magnitude <= 1800 then
                    local d = (mobRoot.Position - playerPos).Magnitude
                    local score = d - (preferred ~= "" and string.find(name, preferred, 1, true) and 125 or 0)
                    if score < bestScore then bestMob, bestScore = mob, score end
                end
            end
            return bestMob
        end

        -- Bones: xét cả 4 loại quái Haunted Castle, chỉ chọn trong khu vực để không đuổi nhầm quái ngoài đảo.
        -- Nếu quái quest đang ở gần thì ưu tiên; nếu không, chọn mục tiêu hợp lệ gần nhất để farm Bones liên tục.
        if selectedFarmTarget == "Bones" then
            if not World3 then return nil end
            local _, _, preferredName = GetHauntedQuestData()
            local preferred = string.lower(tostring(preferredName or ""))
            local boneCenter = HAUNTED_CASTLE_POS
            local bestMob, bestScore = nil, math.huge
            for _, mob in ipairs(enemiesFolder:GetChildren()) do
                local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                local hum = mob:FindFirstChildOfClass("Humanoid")
                local name = string.lower(mob.Name)
                local isBoneMob = string.find(name, "reborn skeleton", 1, true)
                    or string.find(name, "living zombie", 1, true)
                    or string.find(name, "demonic soul", 1, true)
                    or string.find(name, "possessed mummy", 1, true)
                    or string.find(name, "posessed mummy", 1, true)
                if mobRoot and hum and hum.Health > 0 and isBoneMob
                    and (mobRoot.Position - boneCenter).Magnitude <= 1800 then
                    local d = (mobRoot.Position - playerPos).Magnitude
                    local score = d - (preferred ~= "" and string.find(name, preferred, 1, true) and 125 or 0)
                    if score < bestScore then bestMob, bestScore = mob, score end
                end
            end
            return bestMob
        end

        local questName, questLevel, questMobName = GetQuestData()
        local partialEnemy, partialDist = nil, math.huge

        -- LỰA CHỌN MỤC TIÊU CHO CAKE PRINCE (ưu tiên quái đúng quest đang nhận)
        local cakeTargetMob = nil
        if selectedFarmTarget == "Cake Prince" and not isCakePrinceReady and autoQuestEnabled and World3 then
            local _, _, cMob = Q.GetCakeQuestData()
            cakeTargetMob = string.lower(cMob)
        end

        -- LỰA CHỌN MỤC TIÊU CHO ĐẢO XƯƠNG
        local boneTargetMob = nil
        if selectedFarmTarget == "Bones" and autoQuestEnabled and World3 then
            local _, _, hMob = GetHauntedQuestData()
            boneTargetMob = string.lower(hMob)
        end

        for _, v in pairs(enemiesFolder:GetChildren()) do
            local hrp, humanoid = v:FindFirstChild("HumanoidRootPart"), v:FindFirstChild("Humanoid")
            if hrp and humanoid and humanoid.Health > 0 then
                local isMatchingTarget, mobName = false, string.lower(v.Name)
                if selectedFarmTarget == "Auto Level" then
                    local mScore = Q.mobMatches(v.Name, questMobName)
                    if mScore == 2 then
                        isMatchingTarget = true
                    elseif mScore == 1 then
                        local dPart = (hrp.Position - playerPos).Magnitude
                        if dPart < partialDist then partialDist = dPart; partialEnemy = v end
                    end
                elseif selectedFarmTarget == "Cake Prince" then
                    if not isCakePrinceReady then
                        if cakeTargetMob then
                            if string.find(mobName, cakeTargetMob, 1, true) then isMatchingTarget = true end
                        elseif string.find(mobName, "baking staff", 1, true) or string.find(mobName, "head baker", 1, true) or string.find(mobName, "cake guard", 1, true) or string.find(mobName, "cookie crafter", 1, true) or string.find(mobName, "cocoa warrior", 1, true) then 
                            isMatchingTarget = true 
                        end
                    end
                elseif selectedFarmTarget == "Bones" then
                    if boneTargetMob then
                        if string.find(mobName, boneTargetMob, 1, true) then 
                            isMatchingTarget = true 
                        end
                    else
                        if string.find(mobName, "reborn skeleton", 1, true) or string.find(mobName, "living zombie", 1, true) or string.find(mobName, "demonic soul", 1, true) or string.find(mobName, "possessed mummy", 1, true) or string.find(mobName, "posessed mummy", 1, true) then 
                            isMatchingTarget = true 
                        end
                    end
                elseif selectedFarmTarget == "Farm Boss" then
                    if selectedBossTarget ~= "None" and string.find(mobName, string.lower(selectedBossTarget), 1, true)
                        and not (selectedBossTarget == "Warden" and string.find(mobName, "chief", 1, true)) then isMatchingTarget = true end
                end

                if isMatchingTarget then
                    local distance = (hrp.Position - playerPos).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestEnemy = v
                    end
                end
            end
        end

        -- Không có quái trùng tên hoàn toàn -> dùng quái có tên gần giống nhất
        if not closestEnemy and partialEnemy then closestEnemy = partialEnemy end

        -- Dự phòng Cake Prince: quái quest chưa spawn -> đánh quái Đảo Bánh bất kỳ (vẫn tính vào bộ đếm Cake Prince)
        if selectedFarmTarget == "Cake Prince" and not isCakePrinceReady and not closestEnemy then
            for _, v in pairs(enemiesFolder:GetChildren()) do
                local hrp, humanoid = v:FindFirstChild("HumanoidRootPart"), v:FindFirstChild("Humanoid")
                if hrp and humanoid and humanoid.Health > 0 then
                    local mobName = string.lower(v.Name)
                    if string.find(mobName, "baking staff", 1, true) or string.find(mobName, "head baker", 1, true) or string.find(mobName, "cake guard", 1, true) or string.find(mobName, "cookie crafter", 1, true) or string.find(mobName, "cocoa warrior", 1, true) then
                        local distance = (hrp.Position - playerPos).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestEnemy = v
                        end
                    end
                end
            end
        end

        -- Dự phòng nếu quái Quest tại Đảo Xương chưa Spawn: Đánh quái xương bất kỳ
        if selectedFarmTarget == "Bones" and not closestEnemy then
            for _, v in pairs(enemiesFolder:GetChildren()) do
                local hrp, humanoid = v:FindFirstChild("HumanoidRootPart"), v:FindFirstChild("Humanoid")
                if hrp and humanoid and humanoid.Health > 0 then
                    local mobName = string.lower(v.Name)
                    if string.find(mobName, "reborn skeleton", 1, true) or string.find(mobName, "living zombie", 1, true) or string.find(mobName, "demonic soul", 1, true) or string.find(mobName, "possessed mummy", 1, true) or string.find(mobName, "posessed mummy", 1, true) then
                        local distance = (hrp.Position - playerPos).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestEnemy = v
                        end
                    end
                end
            end
        end
    end
    return closestEnemy
end

local function isMobBoss(mobName)
    local lowerName = string.lower(mobName)
    for _, bName in ipairs(seaBosses[currentSeaIndex] or {}) do
        if string.find(lowerName, string.lower(bName), 1, true) then
            return true
        end
    end
    return false
end

_G.MinhHubLoad(62, "Loading Mob Bring feature...")
-- =========================================================--
--            TÍNH NĂNG GOM QUÁI MƯỢT MÀ                    --
-- =========================================================--
local __bringLast, __simLast = 0, 0
RunService.Heartbeat:Connect(function(deltaTime)
    if RAID_FIXED.killAuraActive then return end
    if not bringMobsEnabled or not targetEnemy or type(targetEnemy) ~= "userdata" or not targetEnemy:FindFirstChild("HumanoidRootPart") then return end
    local __now = os.clock()
    -- Không quét và cập nhật physics quái ở mọi frame: giảm tải khi farm bằng Melee/Sword.
    if __now - __bringLast < 0.075 then return end
    __bringLast = __now
    if targetEnemy:FindFirstChild("Humanoid") and targetEnemy.Humanoid.Health <= 0 then return end

    local targetHRP = targetEnemy.HumanoidRootPart
    local enemiesFolder = workspace:FindFirstChild("Enemies") or workspace
    local broughtCount = 0

    if __now - __simLast > 3 then
        __simLast = __now
        pcall(function()
            if sethiddenproperty then
                sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
            end
        end)
    end

    for _, mob in pairs(enemiesFolder:GetChildren()) do
        if broughtCount >= (math.max(maxBringCount, maxAttackTargets) - 1) then break end

        if mob ~= targetEnemy and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
            if not isMobBoss(mob.Name) then
                local mobHrp = mob.HumanoidRootPart
                local dist = (mobHrp.Position - targetHRP.Position).Magnitude

                if dist <= bringRadius then
                    mobHrp.CanCollide = false
                    mobHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    mobHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    mob.Humanoid.PlatformStand = true
                    mob.Humanoid.WalkSpeed = 0
                    mob.Humanoid.JumpPower = 0

                    local targetFlatCF = CFrame.new(targetHRP.Position.X, mobHrp.Position.Y, targetHRP.Position.Z)
                    mobHrp.CFrame = mobHrp.CFrame:Lerp(targetFlatCF, math.clamp(deltaTime * 12, 0, 1))

                    broughtCount = broughtCount + 1
                end
            end
        end
    end
end)

-- =========================================================--
--     FAST ATTACK V3: ĐÁNH NHIỀU MOB CÙNG LÚC (mặc định 2)   --
-- =========================================================--
local RegisterAttack, RegisterHit, THit
FA.crra = 0

-- Remote của combat có thể chưa tồn tại ngay lúc script chạy.
-- Resolver này tự tìm lại định kỳ để Fast Attack không bị kẹt nil vĩnh viễn.
local function resolveCombatRemotes(force)
    if not force and tick() - FA.crra < 2 then return end
    FA.crra = tick()

    RegisterAttack, RegisterHit, THit = nil, nil, nil

    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local net = modules and modules:FindFirstChild("Net")
        if not net then return end

        local function find(name)
            return net:FindFirstChild(name) or net:FindFirstChild(name, true)
        end

        RegisterAttack = find("RE/RegisterAttack")
        RegisterHit    = find("RE/RegisterHit")
        THit           = find("RE/THit")
    end)
end

resolveCombatRemotes(true)

-- Có thể giảm/tăng tùy ping/server.
-- 0.025 = tối đa khoảng 40 chu kỳ/giây về phía client,
-- nhưng server vẫn có thể giới hạn tốc độ thực tế.
local attackInterval = 0.12  -- khoảng 8 lượt/giây; giảm spam remote/giật màn hình khi dùng Melee hoặc Sword
local attackRadius   = 90    -- giữ tầm đánh hợp lý, giảm lượng mục tiêu phải quét
local lastAttackTime = 0

-- FIX: số mob đánh cùng lúc lấy từ cài đặt "Fast Attack Targets" (mặc định 2) thay vì hằng số cố định.
local function getAttackLimit()
    if RAID_FIXED.killAuraActive then
        return RAID_FIXED.killAuraMaxTargets
    end
    return math.clamp(math.floor(tonumber(maxAttackTargets) or 2), 1, 6)
end

-- Người chơi gần đó (trừ bản thân, bỏ qua người đang có ForceField/safe zone) để Fast Attack đánh kèm quái.
function FA.getPlayerTargets(playerPos, limit)
    local list = {}
    if not FA.playerEnabled then return list end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local c = plr.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 and not c:FindFirstChildOfClass("ForceField") then
                local d = (r.Position - playerPos).Magnitude
                if d <= attackRadius then
                    list[#list + 1] = { model = c, hrp = r, dist = d, isPlayer = true }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local out = {}
    for i = 1, math.min(#list, limit) do out[i] = list[i] end
    return out
end

-- Trả về danh sách {model = Model, hrp = HumanoidRootPart}.
-- Mục tiêu chính luôn đứng đầu, các mob còn lại ưu tiên mob gần MỤC TIÊU CHÍNH nhất.
-- Người chơi (nếu bật) được cộng thêm phía sau quái nên đánh cùng lúc cả quái lẫn người.
local function getAliveAttackTargets(maxTargets)
    local char = LocalPlayer.Character
    local playerHrp = char and char:FindFirstChild("HumanoidRootPart")
    if not playerHrp then return {} end

    local playerPos = playerHrp.Position
    local anchorPos = playerPos
    if typeof(targetEnemy) == "Instance" and targetEnemy.Parent then
        local tHrp = targetEnemy:FindFirstChild("HumanoidRootPart")
        if tHrp then anchorPos = tHrp.Position end
    end

    local result = {}
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    local candidates = {}
    local seenModels = {}
    local maxAttackDistance = RAID_FIXED.killAuraActive and RAID_FIXED.killAuraRadius or attackRadius

    -- Cake Prince có thể nằm sâu bên trong Folder/Model trong Enemies.
    -- Bản cũ chỉ quét GetChildren(), nên script có thể bay tới boss nhưng Fast Attack
    -- không đưa boss lồng bên trong vào danh sách mục tiêu để gửi hit.
    local function addAttackCandidate(mob)
        if typeof(mob) ~= "Instance" or not mob:IsA("Model") or seenModels[mob] then return end
        seenModels[mob] = true

        local hum = mob:FindFirstChildOfClass("Humanoid")
        local mobHrp = mob:FindFirstChild("HumanoidRootPart")
        if not hum or not mobHrp or hum.Health <= 0 then return end

        local distPlayer = (mobHrp.Position - playerPos).Magnitude
        if distPlayer <= maxAttackDistance then
            candidates[#candidates + 1] = {
                model = mob,
                hrp = mobHrp,
                dist = (mobHrp.Position - anchorPos).Magnitude,
                priority = (mob == targetEnemy) and 0 or 1,
            }
        end
    end

    if enemiesFolder then
        -- Quét các model trực tiếp để giữ vòng Fast Attack nhẹ; mục tiêu boss lồng sâu
        -- được thêm riêng ở dưới thông qua targetEnemy.
        for _, mob in ipairs(enemiesFolder:GetChildren()) do
            if mob:IsA("Model") then addAttackCandidate(mob) end
        end
    end

    -- Luôn xét mục tiêu chính đang được farm, kể cả khi boss chưa nằm trực tiếp
    -- trong workspace.Enemies. Khoảng cách đánh vẫn được giới hạn như bình thường.
    if typeof(targetEnemy) == "Instance" and targetEnemy.Parent then
        addAttackCandidate(targetEnemy)
    end

    table.sort(candidates, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.dist < b.dist
    end)

    local limit = math.min(getAttackLimit(), maxTargets or 20)
    for _, item in ipairs(candidates) do
        result[#result + 1] = item
        if #result >= limit then break end
    end

    -- Giới hạn tổng số mục tiêu (quái + người chơi). Bản cũ cộng thêm người chơi sau giới hạn
    -- quái, khiến một lượt có thể gửi hit cho nhiều mục tiêu hơn cấu hình.
    local remaining = math.max(0, limit - #result)
    if remaining > 0 then
        for _, p in ipairs(FA.getPlayerTargets(playerPos, math.min(FA.maxPlayers, remaining))) do
            result[#result + 1] = p
        end
    end
    return result
end

function FA.isFarming()
    return autoFarmEnabled
        or autoFarmMaterialEnabled
        or autoRaidEnabled
        or _G.Dungeon
        or _G.AutoLawRaid
        or _G.PirateRaidFarm
        or _G.EliteHunter
        or _G.TyrantFarm
        or _G.TyrantSummon
        or false
end

-- M1 TRÁI ÁC QUỶ ẢO: không click chuột / không click màn hình.
-- Mỗi tool trái có RemoteEvent "LeftClickRemote"; bắn thẳng về server với hướng tới quái
-- (giống hệt khi người chơi bấm M1) nên đánh được quái mà không cần tool:Activate hay VirtualUser.
function FA.getFruitRemote(tool)
    if not tool then return nil end
    local r = tool:FindFirstChild("LeftClickRemote")
    if r and r:IsA("RemoteEvent") then return r end
    return nil
end

function FA.fruitM1(tool, hrp, targetPos)
    local r = FA.getFruitRemote(tool)
    if not r then return false end
    local dir = Vector3.new(0, 0, -1)
    if hrp and targetPos then
        local d = targetPos - hrp.Position
        if d.Magnitude > 0.01 then dir = d.Unit
        else dir = hrp.CFrame.LookVector end
    elseif hrp then
        dir = hrp.CFrame.LookVector
    end
    local ok = pcall(function() r:FireServer(dir, 1) end)
    return ok
end

-- M1 SÚNG ẢO: không click chuột / không click màn hình.
-- Bắn thẳng remote của súng về phía quái (giống lúc người chơi bấm M1). Thử TẤT CẢ đường bắn có thể có:
--   1) Mọi RemoteEvent trong ReplicatedStorage.Modules.Net có tên chứa "shootgun"/"gun" (vd RE/ShootGunEvent)
--      -> FireServer(vị trí, {phần thân mục tiêu...}) và FireServer(vị trí, phần thân)
--   2) Remote nằm TRONG tool súng có tên chứa shoot/fire/gun (RemoteFunctionShoot, RemoteEventShootGun...)
--      -> InvokeServer / FireServer(vị trí, phần thân)
-- Lần đầu cầm mỗi súng sẽ in ra console các remote tìm thấy để dễ chẩn đoán ([MinhHub][Gun]).
FA.gunDiag = FA.gunDiag or {}
function FA.findGunNetRemotes()
    if FA.gunNet and (os.clock() - (FA.gunNetAt or 0)) < 5 then return FA.gunNet end
    FA.gunNetAt = os.clock()
    local list = {}
    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local net = modules and modules:FindFirstChild("Net")
        if not net then return end
        for _, d in ipairs(net:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                local n = string.lower(d.Name)
                if (string.find(n, "shootgun", 1, true) or string.find(n, "gunevent", 1, true)
                    or string.find(n, "gunshoot", 1, true)) and not string.find(n, "register", 1, true) then
                    list[#list + 1] = d
                end
            end
        end
    end)
    FA.gunNet = list
    return list
end

-- Nhận diện súng: theo ToolTip/tên/remote, hoặc người dùng đang chọn loại vũ khí = Gun
function FA.isGunTool(tool)
    if not tool then return false end
    local isGun = isMatchingWeaponType(tool, "Gun")
    if not isGun and (selectedWeapon == "Gun" or _G.SelectWeapon == "Gun") then
        isGun = not isMatchingWeaponType(tool, "Blox Fruit") or tool:FindFirstChild("RemoteFunctionShoot") ~= nil
    end
    return isGun
end

-- AIM ẢO CHO SÚNG: script gốc của súng (tool.Activated) ngắm theo Mouse.Hit/Target = vị trí chuột trên màn hình.
-- Hook đọc Mouse.Hit / Mouse.Target / Mouse.UnitRay: trong lúc bắn thì trả về đúng vị trí QUÁI, nên
-- tool:Activate() (click ảo, KHÔNG click màn hình) bắn trúng quái dù chuột đang ở đâu.
function FA.installGunAim()
    if FA._gunAimHook ~= nil then return FA._gunAimHook end
    FA._gunAimHook = false
    if typeof(hookmetamethod) ~= "function" then return false end
    local okM, mouse = pcall(function() return LocalPlayer:GetMouse() end)
    if not okM or not mouse then return false end
    local wrap = (typeof(newcclosure) == "function") and newcclosure or function(f) return f end
    local isCaller = (typeof(checkcaller) == "function") and checkcaller or function() return false end
    local old
    local okH = pcall(function()
        old = hookmetamethod(game, "__index", wrap(function(self, key)
            if self == mouse and FA._aimPos and os.clock() < (FA._aimUntil or 0) and not isCaller() then
                if key == "Hit" then
                    return CFrame.new(FA._aimPos)
                elseif key == "Target" then
                    if FA._aimPart and FA._aimPart.Parent then return FA._aimPart end
                elseif key == "UnitRay" then
                    local cam = workspace.CurrentCamera
                    local org = cam and cam.CFrame.Position or FA._aimPos
                    local dir = FA._aimPos - org
                    if dir.Magnitude > 0.01 then return Ray.new(org, dir.Unit) end
                end
            end
            return old(self, key)
        end))
    end)
    FA._gunAimHook = okH and old ~= nil
    return FA._gunAimHook
end

function FA.gunM1(tool, hrp, targets)
    if not FA.isGunTool(tool) then return false end

    local first = targets and targets[1]
    if not first or not first.hrp or not first.hrp.Parent then return false end
    if os.clock() - (FA._gunAt or 0) < 0.08 then return true end   -- chống spam, vẫn tính là đã bắn
    FA._gunAt = os.clock()

    local pos = first.hrp.Position
    local parts = {}
    for i = 1, math.min(#targets, 6) do
        if targets[i].hrp and targets[i].hrp.Parent then parts[#parts + 1] = targets[i].hrp end
    end

    local fired = false
    local netCount, toolCount = 0, 0

    -- 1) Remote chung trong Modules.Net
    for _, ev in ipairs(FA.findGunNetRemotes()) do
        if ev.Parent then
            if pcall(function() ev:FireServer(pos, parts) end) then fired = true; netCount = netCount + 1 end
            pcall(function() ev:FireServer(pos, first.hrp) end)
        end
    end

    -- 2) Remote nằm trong tool súng
    for _, d in ipairs(tool:GetDescendants()) do
        local n = string.lower(d.Name)
        if string.find(n, "shoot", 1, true) or string.find(n, "fire", 1, true) or string.find(n, "gun", 1, true) then
            if d:IsA("RemoteFunction") then
                task.spawn(function()
                    pcall(function() d:InvokeServer(pos, first.hrp) end)
                end)
                fired = true; toolCount = toolCount + 1
            elseif d:IsA("RemoteEvent") then
                if pcall(function() d:FireServer(pos, parts) end) then fired = true; toolCount = toolCount + 1 end
                pcall(function() d:FireServer(pos, first.hrp) end)
            end
        end
    end

    -- 3) Bắn bằng chính script của súng (tool:Activate) + aim ảo về phía quái
    --    -> đúng đường bắn thật của game (đủ tham số/ kiểm tra hợp lệ), không click màn hình.
    local nativeFired = false
    if FA.installGunAim() then
        FA._aimPos, FA._aimPart, FA._aimUntil = pos, first.hrp, os.clock() + 0.35
        if os.clock() - (FA._gunActAt or 0) >= 0.1 then
            FA._gunActAt = os.clock()
            nativeFired = pcall(function() tool:Activate() end)
        end
        if nativeFired then fired = true end
    end

    -- Chẩn đoán 1 lần cho mỗi súng
    if not FA.gunDiag[tool.Name] then
        FA.gunDiag[tool.Name] = true
        local kids = {}
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then kids[#kids + 1] = d.ClassName .. ":" .. d.Name end
        end
        local nets = {}
        for _, ev in ipairs(FA.findGunNetRemotes()) do nets[#nets + 1] = ev.Name end
        print(string.format("[MinhHub][Gun] %s | net remote: %s | remote trong tool: %s | aim ảo (hookmetamethod): %s | đã bắn: %s",
            tool.Name, #nets > 0 and table.concat(nets, ", ") or "KHÔNG TÌM THẤY",
            #kids > 0 and table.concat(kids, ", ") or "KHÔNG CÓ", tostring(FA._gunAimHook), tostring(fired)))
    end
    return fired
end

-- AUTO CLICK SÚNG (KHÔNG kéo chuột, KHÔNG xoay camera):
-- Click chuột ảo ngay tại chỗ con trỏ đang đứng; hướng bắn do aim ảo (hook Mouse.Hit/Target) trỏ vào quái.
-- Nếu executor không có hookmetamethod thì chỉ dùng tool:Activate() (cũng không di chuyển chuột).
FA.gunClickEnabled = true
function FA.gunClick(tool, targets)
    if not FA.gunClickEnabled or not FA.isGunTool(tool) then return false end
    if os.clock() - (FA._gunClickAt or 0) < 0.12 then return true end
    local first = targets and targets[1]
    if not first or not first.hrp or not first.hrp.Parent then return false end
    FA._gunClickAt = os.clock()

    -- aim ảo: Mouse.Hit/Target trỏ vào quái trong lúc click (không đụng tới con trỏ thật)
    local aimOk = FA.installGunAim()
    if aimOk then
        FA._aimPos, FA._aimPart, FA._aimUntil = first.hrp.Position, first.hrp, os.clock() + 0.35
    end

    -- Click tại vị trí con trỏ hiện tại, không gửi MouseMove
    local clicked = false
    if okVIM and VirtualInputManager then
        clicked = pcall(function()
            local loc = UserInputService:GetMouseLocation()
            VirtualInputManager:SendMouseButtonEvent(loc.X, loc.Y, 0, true, game, 0)
            task.wait(0.03)
            VirtualInputManager:SendMouseButtonEvent(loc.X, loc.Y, 0, false, game, 0)
        end)
    end
    if not clicked then
        clicked = pcall(function() tool:Activate() end)
    end
    return clicked
end

local function performFastAttackV3()
    if not fastAttackEnabled then return end
    resolveCombatRemotes(false)
    -- Auto: có mục tiêu trong tầm là tự đánh, không cần bật chế độ farm.
    if not (FA.auto or FA.isFarming()) then return end

    local now = tick()
    if now - lastAttackTime < attackInterval then return end
    lastAttackTime = now

    local char = LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not hrp then return end

    local targets = getAliveAttackTargets(getAttackLimit())
    if #targets == 0 then return end

    local tool = char:FindFirstChildOfClass("Tool")
    -- Trái ác quỷ: M1 qua remote riêng; không click chuột.
    local fruitM1 = false
    if tool then
        local aim = targets[1] and targets[1].hrp and targets[1].hrp.Position
        fruitM1 = FA.fruitM1(tool, hrp, aim)
    end

    -- Súng: thử remote bắn riêng; không kết hợp thêm click ảo dư thừa.
    local gunM1 = false
    if tool and not fruitM1 then
        gunM1 = FA.gunM1(tool, hrp, targets)
    end

    local isGunTool = FA.isGunTool(tool)
    -- Auto Click Súng: click chuột ảo vào quái (chạy nền để không chặn vòng Fast Attack)
    if tool and isGunTool and FA.gunClickEnabled then
        _G.MHSpawn(function() pcall(FA.gunClick, tool, targets) end)
    end
    local hasCombatRemote = (RegisterHit ~= nil) or (THit ~= nil)
    -- Khi RegisterHit/THit có sẵn, dùng một luồng đánh qua remote. Tránh gọi Activate +
    -- VirtualUser đồng thời vì dễ tạo input/animation trùng và làm giật màn hình.
    if tool and not fruitM1 and not gunM1 and not isGunTool and not hasCombatRemote
        and os.clock() - (FA._toolActivateAt or 0) >= 0.16 then
        FA._toolActivateAt = os.clock()
        pcall(function() tool:Activate() end)
    end

    -- Chỉ dùng click ảo làm phương án dự phòng khi KHÔNG có tool và combat remote.
    if not tool and not fruitM1 and not gunM1 and not isGunTool and not hasCombatRemote
        and okVU and VirtualUser and os.clock() - (FA._vuAt or 0) > 0.18 then
        FA._vuAt = os.clock()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(800, 800))
        end)
    end

    -- Gửi một gói RegisterHit cho cả danh sách mục tiêu; không lặp RegisterHit/THit
    -- nhiều lần trong cùng một lượt tấn công.
    local validTargets, pairList = {}, {}
    for i = 1, #targets do
        local t = targets[i]
        if t and t.model and t.model.Parent and t.hrp and t.hrp.Parent then
            validTargets[#validTargets + 1] = t
            pairList[#pairList + 1] = { t.model, t.hrp }
        end
    end
    if #validTargets == 0 then return end

    if RegisterHit then
        if RegisterAttack then
            pcall(function() RegisterAttack:FireServer(0) end)
        end
        pcall(function()
            RegisterHit:FireServer(validTargets[1].hrp, pairList)
        end)
    elseif THit then
        -- Remote tương thích cũ chỉ dùng khi không có RegisterHit.
        for i = 1, math.min(#validTargets, getAttackLimit()) do
            local t = validTargets[i]
            pcall(function() THit:FireServer(t.hrp) end)
        end
    elseif RegisterAttack then
        pcall(function() RegisterAttack:FireServer(0) end)
    end
end

-- Độ cao bay khi farm (theo thanh "Độ cao Farm")
function FA.hoverH()
    local h = (farmDistanceHeight and farmDistanceHeight > 0) and farmDistanceHeight or 35
    -- Trái Ác Quỷ dùng cùng độ cao với Melee / Sword (theo thanh "Độ cao Farm").
    -- Muốn hạ thấp riêng khi cầm fruits: đặt _G.FruitHoverHeight = số (mặc định: không dùng).
    local fh = tonumber(_G.FruitHoverHeight)
    if fh then
        local ch = LocalPlayer.Character
        local tl = ch and ch:FindFirstChildOfClass("Tool")
        if tl and isMatchingWeaponType(tl, "Blox Fruit") then
            h = math.min(h, fh)
        end
    end
    return h
end

-- Đứng trên đầu quái MƯỢT, không rung màn hình:
--  * giữ nguyên hướng nhân vật (chỉ xoay quanh trục Y), không copy hướng quay của quái
--  * vùng chết ~1.5 studs: lệch nhỏ thì không chỉnh (trước đây chỉnh 20 lần/giây làm camera rung)
--  * lệch vừa thì kéo dần (lerp), lệch lớn mới nhảy thẳng tới
function FA.hoverSet(hrp, pos)
    local cur = hrp.Position
    local d = (pos - cur).Magnitude
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    if d < 1.5 then return end
    local _, yaw, _ = hrp.CFrame:ToOrientation()
    local nxt = (d > 25) and pos or cur:Lerp(pos, 0.45)
    hrp.CFrame = CFrame.new(nxt) * CFrame.fromOrientation(0, yaw, 0)
end

-- Vòng lặp riêng giúp Fast Attack không phụ thuộc FPS của Heartbeat.
_G.MHSpawn(function()
    while true do
        task.wait(attackInterval)
        if fastAttackEnabled then
            pcall(performFastAttackV3)
        end
    end
end)

_G.MinhHubLoad(68, "Loading Auto Elite Hunter...")
-- =========================================================--
--      AUTO ELITE HUNTER (Sea 3) + THẺ TRẠNG THÁI SERVER     --
-- =========================================================--
-- Quy trình đúng (khớp cách game hoạt động):
--   1) CHỈ gọi CommF_("EliteHunter") khi CHƯA có quest Elite (spam remote khi đang có quest làm boss bị reset).
--   2) Có quest -> boss (Diablo / Urban / Deandre) nằm trong ReplicatedStorage cho tới khi tới gần.
--      -> bay tới vị trí đó, boss tải ra trong workspace.Enemies thì treo trên đầu & Fast Attack.
--   3) Boss chết -> quest tắt -> nhận quest mới.
function EH.findBoss()
    -- Ưu tiên boss đã xuất hiện thật trong Workspace.Enemies.
    -- Không bắt buộc tên phải khớp 100% vì một số server/executor có thể
    -- thêm hậu tố vào tên Model khi Elite vừa spawn.
    local ef = workspace:FindFirstChild("Enemies")
    if ef then
        local partial = nil

        for _, m in ipairs(ef:GetChildren()) do
            local hum = m:FindFirstChildOfClass("Humanoid")
            local hrp = m:FindFirstChild("HumanoidRootPart")

            if hum and hrp and hum.Health > 0 then
                local modelName = string.lower(tostring(m.Name))

                for _, n in ipairs(EH.names) do
                    local wanted = string.lower(tostring(n))

                    -- Khớp tuyệt đối được ưu tiên.
                    if m.Name == n then
                        return m, "live"
                    end

                    -- Hỗ trợ tên có hậu tố/format khác nhưng vẫn chứa tên Elite.
                    if not partial and string.find(modelName, wanted, 1, true) then
                        partial = m
                    end
                end
            end
        end

        if partial then
            return partial, "live"
        end
    end

    -- Boss chưa tải: chỉ tính là "đã spawn" khi đang có quest Elite.
    -- Kiểm tra cả model chính xác và model có tên chứa tên Elite.
    if EH.questActive() then
        for _, n in ipairs(EH.names) do
            local m = ReplicatedStorage:FindFirstChild(n)
            local mh = m and m:FindFirstChild("HumanoidRootPart")
            local mhum = m and m:FindFirstChildOfClass("Humanoid")
            if mh and (not mhum or mhum.Health > 0) then
                return m, "stored"
            end
        end

        for _, m in ipairs(ReplicatedStorage:GetChildren()) do
            local modelName = string.lower(tostring(m.Name))
            local mh = m:FindFirstChild("HumanoidRootPart")
            local mhum = m:FindFirstChildOfClass("Humanoid")
            if mh and (not mhum or mhum.Health > 0) then
                for _, n in ipairs(EH.names) do
                    if string.find(modelName, string.lower(tostring(n)), 1, true) then
                        return m, "stored"
                    end
                end
            end
        end
    end

    return nil, nil
end

-- Quest Elite đang hoạt động: thấy trên GUI, hoặc vừa nhận quest thành công (dự phòng khi không đọc được GUI)
function EH.questActive()
    local ok, has = pcall(function() return EH.questState() end)
    if ok and has then return true end
    return (tick() - (EH.questTakenAt or 0)) < 180
end

function EH.findNamed(name)
    local ef = workspace:FindFirstChild("Enemies")
    local live = false
    if ef then
        for _, m in ipairs(ef:GetChildren()) do
            local hum = m:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and string.find(string.lower(m.Name), string.lower(name), 1, true) then live = true break end
        end
    end
    local stored = ReplicatedStorage:FindFirstChild(name) ~= nil
    return live, stored
end

-- Đang có quest Elite chưa? (đọc GUI Main.Quest, tên boss nằm trong tiêu đề quest)
function EH.questState()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local q = main and main:FindFirstChild("Quest")
    if not q or not q.Visible then return false, nil end
    for _, d in ipairs(q:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text ~= "" then
            local t = string.lower(d.Text)
            for _, n in ipairs(EH.names) do
                if string.find(t, string.lower(n), 1, true) then return true, n end
            end
        end
    end
    return false, nil
end

function EH.refreshInventory()
    EH.invAt = tick()
    local chalice, fist = false, false
    local function scan(c)
        if not c then return end
        for _, t in ipairs(c:GetDescendants()) do
            local n = string.lower(t.Name)
            if string.find(n, "god's chalice", 1, true) or string.find(n, "gods chalice", 1, true) then chalice = true end
            if string.find(n, "fist of darkness", 1, true) then fist = true end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack")); scan(LocalPlayer.Character)
    local commF = getCommF()
    if commF then
        local ok, inv = pcall(function() return commF:InvokeServer("getInventory") end)
        if ok and type(inv) == "table" then
            EH.invOk = true
            for _, it in pairs(inv) do
                local n = type(it) == "table" and it.Name or nil
                if n == "God's Chalice" then chalice = true end
                if n == "Fist of Darkness" then fist = true end
            end
        end
    end
    EH.hasChalice, EH.hasFist = chalice, fist
end

-- QUÉT SERVER XEM ELITE (Diablo / Urban / Deandre) ĐÃ XUẤT HIỆN CHƯA.
-- Trả về: trạng thái, tên boss, khoảng cách (studs), nguồn ("live" / "stored" / "quest").
-- Trước đây chỉ báo "Sắp spawn" khi ĐÃ có quest nên Elite spawn rồi mà chưa nhận quest vẫn hiện "Chưa có".
-- Giờ quét độc lập với quest, theo 3 nguồn:
--   1) workspace.Enemies : boss đã tải trong map (sống).
--   2) ReplicatedStorage : boss đã spawn nhưng ở xa nên map chưa tải ra.
--   3) GUI quest         : đã nhận quest và tiêu đề có tên boss.
function EH.getEliteState()
    local function matches(name)
        local low = string.lower(tostring(name))
        for _, wanted in ipairs(EH.names) do
            local w = string.lower(wanted)
            if low == w or string.find(low, w, 1, true) then return true end
        end
        return false
    end

    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local function distTo(inst)
        if not myRoot or not inst then return nil end
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok and cf then return (cf.Position - myRoot.Position).Magnitude end
        return nil
    end

    -- 1) Boss đã tải trong map
    local ef = workspace:FindFirstChild("Enemies")
    if ef then
        for _, m in ipairs(ef:GetChildren()) do
            if matches(m.Name) then
                local hum = m:FindFirstChildOfClass("Humanoid")
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hrp and (not hum or hum.Health > 0) then
                    return "Đã spawn", m.Name, distTo(m), "live"
                end
            end
        end
    end

    -- 2) Boss đã spawn nhưng chưa tải map (nằm trong ReplicatedStorage)
    for _, m in ipairs(ReplicatedStorage:GetChildren()) do
        if (m:IsA("Model") or m:IsA("BasePart")) and matches(m.Name) then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hrp and (not hum or hum.Health > 0) then
                return "Đã spawn", m.Name, distTo(m), "stored"
            end
        end
    end

    -- 3) Đã nhận quest Elite
    local okQ, hasQ, qName = pcall(EH.questState)
    if okQ and hasQ then
        return "Đã nhận quest", qName, nil, "quest"
    end
    if (tick() - (EH.questTakenAt or 0)) < 180 then
        return "Đã nhận quest", nil, nil, "quest"
    end

    return "Chưa spawn", nil, nil, nil
end

function EH.getDarkbeardState()
    local ef = workspace:FindFirstChild("Enemies")
    if ef then
        for _, m in ipairs(ef:GetChildren()) do
            local n = string.lower(m.Name)
            if string.find(n, "darkbeard", 1, true) or string.find(n, "blackbeard", 1, true) or string.find(n, "dark beard", 1, true) then
                local hum = m:FindFirstChildOfClass("Humanoid")
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hrp and (not hum or hum.Health > 0) then
                    return "Đã spawn", m.Name
                end
            end
        end
    end
    for _, wanted in ipairs({"Darkbeard", "Blackbeard"}) do
        local m = ReplicatedStorage:FindFirstChild(wanted)
        if m and m:FindFirstChild("HumanoidRootPart") then
            return "Sắp spawn", wanted
        end
    end
    return "Chưa có", nil
end

function EH.getLastEliteKillText()
    if not EH.lastKillAt or EH.lastKillAt <= 0 then return "Chưa hạ Elite" end
    return "Hạ Elite gần nhất: " .. EH.hms(tick() - EH.lastKillAt) .. " trước"
end

function EH.fmt(t)
    t = math.max(0, math.floor(t))
    return string.format("%02d:%02d:%02d", math.floor(t / 3600), math.floor(t % 3600 / 60), t % 60)
end

-- Giữ nhân vật lơ lửng mỗi frame (noclip bật nên nếu không giữ sẽ rơi xuyên map)
RunService.Heartbeat:Connect(function()
    if not _G.EliteHunter then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local boss = EH.hoverBoss
    if boss and boss.Parent then
        local bh = boss:FindFirstChild("HumanoidRootPart")
        if bh then
            local h = FA.hoverH()
            local pos = bh.Position + Vector3.new(0, h, 0)
            if (hrp.Position - pos).Magnitude <= 100 then
                hrp.CFrame = CFrame.new(pos)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    elseif EH.holdPos then
        hrp.CFrame = CFrame.new(EH.holdPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end)

_G.MHSpawn(function()
    local lastQuest, lastProg = 0, 0
    while task.wait(0.2) do
        if _G.EliteHunter and World3 then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then EH.hoverBoss = nil; EH.holdPos = nil; return end
                if not Q.SmartController.canRun("elite") then
                    _G.EliteBusy = false
                    EH.hoverBoss = nil; EH.holdPos = nil
                    EH.status = "Tạm dừng (" .. Q.SmartController.getStatus() .. ")"
                    if currentFlyTween then pcall(function() currentFlyTween:Cancel() end); currentFlyTween = nil end
                    return
                end

                local commF = getCommF()
                local boss, where = EH.findBoss()
                local hasQuest = EH.questState()
                EH.hasQuest = hasQuest

                if commF and tick() - lastProg >= 20 then
                    lastProg = tick()
                    local ok, reply = pcall(function() return commF:InvokeServer("EliteHunter", "Progress") end)
                    if ok and reply ~= nil then EH.progress = tostring(reply) end
                end

                -- ===== 1) Boss đã xuất hiện -> nhận diện ngay -> bay động -> đánh =====
                if boss and where == "live" then
                    local bh = boss:FindFirstChild("HumanoidRootPart")
                    local bHum = boss:FindFirstChildOfClass("Humanoid")

                    if bh and bHum and bHum.Health > 0 then
                        _G.EliteBusy = true
                        EH.wasLive = true
                        EH.holdPos = nil
                        EH.targetName = boss.Name
                        pcall(equipSelectedWeapon)
                        targetEnemy = boss

                        local h = FA.hoverH()
                        local targetPos = bh.Position + Vector3.new(0, h, 0)
                        local dist = (hrp.Position - targetPos).Magnitude
                        EH.targetDistance = dist

                        -- Khi Elite vừa spawn ở xa, luôn lấy vị trí boss mới nhất
                        -- thay vì khóa vào CFrame cũ.
                        if dist > 35 then
                            EH.hoverBoss = nil
                            EH.status = "Bay tới Elite " .. tostring(boss.Name) .. "... [" .. math.floor(dist) .. " studs]"

                            if currentFlyTween then
                                pcall(function() currentFlyTween:Cancel() end)
                                currentFlyTween = nil
                            end
                            EH.flyBoss = boss

                            if _G.FlyStraight then
                                _G.FlyStraight(
                                    function()
                                        if not boss.Parent then return nil end
                                        local root = boss:FindFirstChild("HumanoidRootPart")
                                        local liveHum = boss:FindFirstChildOfClass("Humanoid")
                                        if not root or not liveHum or liveHum.Health <= 0 then return nil end
                                        return root.Position + Vector3.new(0, h, 0)
                                    end,
                                    math.max(tonumber(flySpeed) or 190, 220),
                                    function()
                                        return _G.EliteHunter
                                            and boss.Parent ~= nil
                                            and bHum.Parent ~= nil
                                            and bHum.Health > 0
                                            and not _G.FruitPickupBusy
                                            and not _G.PirateRaidBusy
                                            and not RAID_FIXED.running
                                            and not RAID_FIXED.starting
                                    end,
                                    22
                                )
                            else
                                -- Fallback cho bản cũ nếu FlyStraight chưa tồn tại.
                                local fresh = boss:FindFirstChild("HumanoidRootPart")
                                if fresh then
                                    currentFlyTween = TweenService:Create(
                                        hrp,
                                        TweenInfo.new(math.max(0.15, dist / math.max(tonumber(flySpeed) or 190, 1)), Enum.EasingStyle.Linear),
                                        {CFrame = CFrame.new(fresh.Position + Vector3.new(0, h, 0))}
                                    )
                                    currentFlyTween:Play()
                                end
                            end
                        else
                            if currentFlyTween then
                                pcall(function() currentFlyTween:Cancel() end)
                                currentFlyTween = nil
                            end
                            EH.flyBoss = nil
                            EH.hoverBoss = boss
                            EH.status = "Đang đánh " .. tostring(boss.Name) .. " [" .. math.floor(dist) .. " studs]"
                        end

                        return
                    end
                end

                -- Boss vừa chết / biến mất
                if EH.wasLive then
                    EH.wasLive = false
                    EH.lastKillAt = tick()
                    targetEnemy = nil
                    EH.flyBoss = nil
                    EH.hoverBoss = nil
                    EH.questTakenAt = 0
                    EH.targetName = "-"
                    EH.targetDistance = 0
                    EH.status = "Elite đã bị hạ - đang tìm Elite tiếp theo..."
                    if currentFlyTween then currentFlyTween:Cancel(); currentFlyTween = nil end
                    lastQuest = 0
                end

                -- ===== 2) Boss chưa tải (nằm trong ReplicatedStorage) -> bay tới =====
                if boss and where == "stored" then
                    _G.EliteBusy = true
                    EH.hoverBoss = nil
                    EH.holdPos = nil
                    EH.status = "Bay tới " .. boss.Name .. " để boss xuất hiện..."
                    local bpos = boss.HumanoidRootPart.Position + Vector3.new(0, 35, 0)
                    _G.MHSpawn(function() pcall(function() LocalPlayer:RequestStreamAroundAsync(bpos) end) end)
                    flyTo(CFrame.new(bpos), flySpeed, function()
                        if not _G.EliteHunter then return false end
                        local _, w = EH.findBoss()
                        return w == "stored"
                    end)
                    EH.holdPos = bpos
                    return
                end

                -- ===== 3) Chưa có boss: nhận quest (chỉ khi CHƯA có quest Elite) =====
                _G.EliteBusy = false
                EH.hoverBoss = nil
                if not EH.holdPos then EH.holdPos = hrp.Position end

                if hasQuest then
                    EH.status = "Đã có quest Elite - đứng chờ, boss spawn sẽ tự bay tới đánh"
                elseif commF and tick() - lastQuest >= 6 then
                    lastQuest = tick()
                    local ok, reply = pcall(function() return commF:InvokeServer("EliteHunter") end)
                    if ok then
                        EH.lastReply = tostring(reply)
                        local low = string.lower(EH.lastReply)
                        if string.find(low, "come back", 1, true) or string.find(low, "nothing", 1, true) then
                            EH.status = "Chưa có Elite mới (hồi chiêu) - đang chờ & thử lại..."
                        else
                            EH.questTakenAt = tick()
                            EH.status = "Đã nhận quest Elite - chờ boss spawn..."
                        end
                    else
                        EH.status = "Lỗi gọi EliteHunter (kiểm tra Sea 3)"
                    end
                elseif not hasQuest then
                    EH.status = "Chờ gọi lại quest Elite... (" .. string.sub(tostring(EH.lastReply), 1, 45) .. ")"
                end
            end)
        else
            if _G.EliteBusy then _G.EliteBusy = false end
            EH.hoverBoss = nil
            EH.holdPos = nil
        end
    end
end)

-- Đếm "mắt" tượng chim ở Tiki Outpost (Tyrant of the Skies): đếm phần tử tên có "eye" đang đỏ.
-- LƯU Ý: đây là cách dò theo tên/màu, nếu game đổi cấu trúc sẽ hiện "? Eyes".
function EH.countEyes()
    local map = workspace:FindFirstChild("Map")
    local tiki = map and (map:FindFirstChild("TikiOutpost") or map:FindFirstChild("Tiki Outpost"))
    if not tiki then return nil end
    local lit, total = 0, 0
    for _, d in ipairs(tiki:GetDescendants()) do
        if d:IsA("BasePart") and string.find(string.lower(d.Name), "eye", 1, true) then
            total = total + 1
            local c = d.Color
            if c.R > 0.6 and c.G < 0.4 and c.B < 0.4 then lit = lit + 1 end
        end
    end
    if total == 0 then return nil end
    return lit, total
end

function EH.hms(t)
    t = math.max(0, math.floor(t))
    return string.format("%dh %dm %ds", math.floor(t / 3600), math.floor(t % 3600 / 60), t % 60)
end

-- Đã bỏ vòng lặp cập nhật trạng thái riêng của TAB Boss.

_G.MinhHubLoad(74, "Loading Auto Boss / Tyrant...")
-- =========================================================--
--   AUTO FARM + TRIỆU HỒI TYRANT OF THE SKIES (Sea 3, Tiki Outpost)
-- =========================================================--
-- Cơ chế game: 2 tượng chim ở Tiki Outpost có 4 mắt. Mỗi mắt cần ~75 quái Tiki Outpost bị hạ (tổng ~300, hạ quái
-- mỗi bên đảo thắp 1 tượng; người chơi khác trong server cũng được tính). Đủ 4 mắt đỏ -> đập các BÌNH đất sét quanh
-- khu tượng -> Tyrant of the Skies (lv 2600, luôn bay trên không) xuất hiện.
-- Script: farm quái luân phiên 2 bên đảo -> khi đủ mắt (hoặc ước lượng đủ số quái) chuyển sang đập bình -> đánh boss.
-- LƯU Ý: số mắt đọc theo tên/màu (có thể không chính xác), tên bình/toạ độ có thể lệch nếu game đổi -> xem thanh trạng thái.
TY.SIDE_A = Vector3.new(-16550, 85, -230)   -- Isle Outlaw / Island Boy
TY.SIDE_B = Vector3.new(-16350, 90, 1100)   -- Sun-kissed Warrior / Isle Champion
TY.NAMES  = {
    [1] = {"isle outlaw", "island boy"},
    [2] = {"sun-kissed warrior", "isle champion"},
}
TY.EXTRA  = {"serpent hunter", "skull slayer"}   -- quái nhiệm vụ 3 của Tiki Outpost (cũng tính vào bộ đếm)

function TY.findBoss()
    local ef = workspace:FindFirstChild("Enemies")
    if not ef then return nil end
    for _, m in ipairs(ef:GetChildren()) do
        if string.find(string.lower(m.Name), "tyrant", 1, true) then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then return m end
        end
    end
    return nil
end

function TY.tikiModel()
    local map = workspace:FindFirstChild("Map")
    return map and (map:FindFirstChild("TikiOutpost") or map:FindFirstChild("Tiki Outpost"))
end

-- Tìm các bình đất sét (đập để triệu hồi). Dò theo tên: vase / jar / urn / pot / clay.
function TY.getVases(myPos)
    if tick() - TY.vaseAt < 4 and #TY.vases > 0 then return TY.vases end
    TY.vaseAt = tick()
    local list = {}
    local tiki = TY.tikiModel()
    if tiki then
        for _, d in ipairs(tiki:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Model") then
                local n = string.lower(d.Name)
                if string.find(n, "vase", 1, true) or string.find(n, "jar", 1, true) or string.find(n, "urn", 1, true)
                    or string.find(n, "clay", 1, true) or n == "pot" or string.find(n, "^pot[%s_%d]") or string.find(n, "[%s_]pot$") then
                    local part = d:IsA("BasePart") and d or (d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart"))
                    if part and not (d:IsA("BasePart") and d.Parent and d.Parent:IsA("Model") and string.find(string.lower(d.Parent.Name), "vase", 1, true)) then
                        list[#list + 1] = part
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return (a.Position - myPos).Magnitude < (b.Position - myPos).Magnitude end)
    TY.vases = list
    return list
end

-- Di chuyển mượt (giống Elite): bám mục tiêu > bay tới điểm > giữ vị trí
RunService.Heartbeat:Connect(function(dt)
    if not (_G.TyrantFarm or _G.TyrantSummon) then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local goal
    local m = TY.hover
    if m and m.Parent then
        local mh = m:FindFirstChild("HumanoidRootPart")
        if mh then
            local h = FA.hoverH()
            goal = mh.Position + Vector3.new(0, h, 0)
        end
    end
    goal = goal or TY.goal or TY.hold
    if not goal then return end
    local cur = hrp.Position
    local delta = goal - cur
    local dist = delta.Magnitude
    local newPos
    if dist <= 1.5 then newPos = goal
    else newPos = cur + delta.Unit * math.min(dist, (flySpeed or 190) * math.min(dt, 0.05)) end
    hrp.CFrame = (hrp.CFrame - hrp.CFrame.Position) + newPos
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end)

function TY.swing(char)
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local m = (TY.hover and TY.hover.Parent and TY.hover) or (TY.curMob and TY.curMob.Parent and TY.curMob)
        local mh = m and m:FindFirstChild("HumanoidRootPart")
        if FA.fruitM1(tool, hrp, mh and mh.Position) then return end  -- trái ác quỷ: M1 ảo, không click màn hình
        if FA.isGunTool(tool) then
            -- súng: chỉ bắn bằng remote (M1 ảo), tuyệt đối không click màn hình
            if mh then FA.gunM1(tool, hrp, {{model = m, hrp = mh}}) end
            return
        end
        pcall(function() tool:Activate() end)
        return   -- đã có tool: không cần VirtualUser click thêm
    end
    if okVU and VirtualUser then
        pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton1(Vector2.new(800, 800)) end)
    end
end

function TY.doFarm(hrp, char)
    if getLevel() < 2450 then TY.status = "Cần level 2450+ để farm quái Tiki Outpost" end
    -- ghi nhận quái vừa hạ
    if TY.curMob then
        local hum = TY.curMob:FindFirstChildOfClass("Humanoid")
        if not TY.curMob.Parent or not hum or hum.Health <= 0 then
            TY.kills = TY.kills + 1
            TY.sideKills = TY.sideKills + 1
            TY.curMob = nil
        end
    end
    -- mỗi bên ~150 quái (2 mắt x 75) rồi đổi sang bên kia
    if TY.sideKills >= 150 then
        TY.side = (TY.side == 1) and 2 or 1
        TY.sideKills = 0
    end
    local anchor = (TY.side == 1) and TY.SIDE_A or TY.SIDE_B
    local best, bestD = nil, math.huge
    local ef = workspace:FindFirstChild("Enemies")
    if ef then
        for _, m in ipairs(ef:GetChildren()) do
            local hum = m:FindFirstChildOfClass("Humanoid")
            local mh = m:FindFirstChild("HumanoidRootPart")
            if hum and mh and hum.Health > 0 and (mh.Position - anchor).Magnitude <= 750 then
                local low = string.lower(m.Name)
                local ok = false
                for _, n in ipairs(TY.NAMES[TY.side]) do if string.find(low, n, 1, true) then ok = true end end
                for _, n in ipairs(TY.EXTRA) do if string.find(low, n, 1, true) then ok = true end end
                if ok then
                    local d = (mh.Position - hrp.Position).Magnitude
                    if d < bestD then best, bestD = m, d end
                end
            end
        end
    end
    if best then
        TY.curMob = best
        targetEnemy = best
        TY.hover = best
        TY.goal = nil
        TY.hold = nil
        TY.status = "Farm quái " .. best.Name .. " (bên " .. (TY.side == 1 and "A" or "B") .. ", " .. TY.sideKills .. "/150)"
    else
        TY.hover = nil
        targetEnemy = nil
        local first = TY.NAMES[TY.side][1]
        local spawnPos = GetQuestMobSpawn and GetQuestMobSpawn(first, anchor) or anchor
        TY.goal = (spawnPos or anchor) + Vector3.new(0, 35, 0)
        TY.status = "Bay tới khu quái bên " .. (TY.side == 1 and "A" or "B") .. " chờ quái spawn..."
    end
end

function TY.doSummon(hrp, char)
    TY.hover = nil
    targetEnemy = nil
    local vases = TY.getVases(hrp.Position)
    local target
    for _, v in ipairs(vases) do
        if v.Parent and (TY.vaseTry[v] or 0) < 14 then target = v break end
    end
    if not target then
        local tiki = TY.tikiModel()
        local center
        if tiki then
            local ok, cf = pcall(function() return tiki:GetPivot() end)
            if ok and cf then center = cf.Position end
        end
        TY.goal = (center or TY.SIDE_B) + Vector3.new(0, 60, 0)
        TY.status = (#vases == 0) and "Không thấy bình ở Tiki Outpost - đang chờ boss..." or "Đã đập hết bình - chờ Tyrant xuất hiện..."
        return
    end
    TY.goal = target.Position + Vector3.new(0, 5, 0)
    local d = (hrp.Position - target.Position).Magnitude
    if d <= 14 then
        TY.status = "Đang đập bình triệu hồi (" .. tostring(target.Name) .. ")"
        TY.vaseTry[target] = (TY.vaseTry[target] or 0) + 1
        TY.swing(char)
        local model = target.Parent
        if RegisterHit then
            if RegisterAttack then pcall(function() RegisterAttack:FireServer(0) end) end
            pcall(function() RegisterHit:FireServer(target, {{model, target}}) end)
        end
    else
        TY.status = "Bay tới bình gần nhất..."
    end
end

_G.MHSpawn(function()
    while task.wait(0.2) do
        if (_G.TyrantFarm or _G.TyrantSummon) and World3 then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then TY.hover = nil; TY.goal = nil; TY.hold = nil; return end
                if not Q.SmartController.canRun("tyrant") then
                    TY.hover = nil; TY.goal = nil; TY.hold = nil
                    TY.status = "Tạm dừng (" .. Q.SmartController.getStatus() .. ")"
                    if currentFlyTween then pcall(function() currentFlyTween:Cancel() end); currentFlyTween = nil end
                    return
                end
                if currentFlyTween then currentFlyTween:Cancel(); currentFlyTween = nil end
                pcall(equipSelectedWeapon)

                -- đọc số mắt (dò theo tên/màu, có thể là nil)
                local okE, lit, total = pcall(EH.countEyes)
                if okE then TY.eyeLit, TY.eyeTotal = lit, total else TY.eyeLit, TY.eyeTotal = nil, nil end

                -- Boss đã xuất hiện -> đánh
                local boss = TY.findBoss()
                if boss then
                    TY.bossSeen = true
                    TY.hover = boss; TY.goal = nil; TY.hold = nil
                    targetEnemy = boss
                    TY.status = "Fighting Tyrant of the Skies"
                    return
                end
                if TY.bossSeen then
                    TY.bossSeen = false
                    TY.hover = nil; targetEnemy = nil
                    TY.kills = 0; TY.sideKills = 0; TY.phase = "farm"; TY.vaseTry = {}
                    TY.status = "Tyrant of the Skies defeated"
                end

                -- Chọn giai đoạn
                if _G.TyrantSummon and not _G.TyrantFarm then
                    TY.phase = "summon"
                elseif TY.phase == "farm" then
                    if (TY.eyeLit and TY.eyeLit >= 4) or TY.kills >= 330 then
                        TY.phase = "summon"; TY.phaseAt = tick(); TY.vaseTry = {}; TY.vaseAt = 0
                    end
                elseif TY.phase == "summon" and tick() - TY.phaseAt > 150 then
                    -- đập bình 150s mà boss chưa ra -> quay lại farm thêm quái
                    TY.phase = "farm"; TY.kills = 0; TY.sideKills = 0
                end

                if TY.phase == "summon" then TY.doSummon(hrp, char) else TY.doFarm(hrp, char) end
            end)
        else
            TY.hover = nil; TY.goal = nil; TY.hold = nil
        end
    end
end)

-- TỰ ĐỘNG BẬT FAST ATTACK: mỗi lần bắt đầu farm (tắt -> bật) sẽ tự bật lại Fast Attack.
-- Sau đó bạn vẫn có thể tắt tay trong menu mà không bị ép bật lại.
_G.MHSpawn(function()
    while true do
        task.wait(0.5)
        local farming = FA.isFarming()
        if FA.auto and farming and not FA.wasFarming then
            fastAttackEnabled = true
        end
        FA.wasFarming = farming
    end
end)

-- LOGIC AUTO FARM PIRATE RAID (SEA 3 - CASTLE ON THE SEA)
-- Pirate Raid: sự kiện chỉ có ở Sea 3, cứ 75 phút hải tặc (quái Sea 1/2) kéo tới sân Castle on the Sea; đánh hết sẽ có
-- 1 con "trâu" cuối, ai tung đòn kết liễu nhận 1 Trái Ác Quỷ ngẫu nhiên, ai hạ >= 1 hải tặc nhận 100 Fragments.
-- Lâu đài không có quái thường trú nên MỌI quái trong workspace.Enemies nằm gần lâu đài chính là hải tặc của sự kiện.
-- Cách chạy:
--   * Nghe thông báo "Pirates have been spotted approaching the castle!" -> bay thẳng tới lâu đài chờ sẵn.
--   * Có hải tặc -> tạm dừng các chế độ farm khác, bay thẳng tới con gần nhất, treo trên đầu và đánh (dùng Fast Attack
--     + Bring Mob có sẵn). Hết hải tặc vẫn chờ 25 giây vì con cuối chỉ xuất hiện sau khi dọn xong đợt đầu.
--   * Kết thúc -> trả quyền điều khiển, Auto Farm thường tự chạy lại.
;(function()
    local CASTLE_FALLBACK = Vector3.new(-5278, 314, -2898)  -- giữa sân lâu đài và khu nút Raid (gần đúng)
    local GRACE_SECONDS   = 25
    local ARM_SECONDS     = 600

    local armedUntil  = 0
    local lastSeen    = 0
    local engaged     = false
    local lastHoldPos = nil
    local statusText  = "Disabled"

    local function setStatus(t)
        _G.PirateRaidStatus = t
        if t ~= statusText then
            statusText = t
            if _G.PirateRaidDebug then print("[PirateRaid]", t) end
        end
    end

    -- Tâm lâu đài: lấy từ Map["Boat Castle"] nếu hợp lý, không thì dùng toạ độ dự phòng
    local function castleCenter()
        local map = workspace:FindFirstChild("Map")
        local castle = map and map:FindFirstChild("Boat Castle")
        if castle then
            local ok, cf = pcall(function() return castle:GetPivot() end)
            if ok and cf and (cf.Position - CASTLE_FALLBACK).Magnitude < 1500 then return cf.Position end
        end
        return CASTLE_FALLBACK
    end

    -- Hải tặc đang sống quanh lâu đài (bỏ qua boss Raid rip_indra vì phải đánh theo đội)
    local function pirates(center)
        local list = {}
        local folder = workspace:FindFirstChild("Enemies")
        if not folder then return list end
        local radius = tonumber(_G.PirateRaidRadius) or 900
        for _, m in ipairs(folder:GetChildren()) do
            local hum = m:FindFirstChildOfClass("Humanoid")
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and not string.find(string.lower(m.Name), "indra", 1, true)
                and (hrp.Position - center).Magnitude <= radius then
                list[#list + 1] = { model = m, hrp = hrp, hum = hum }
            end
        end
        return list
    end

    -- Nghe thông báo bắt đầu sự kiện (nếu game đưa vào GUI hoặc chat hệ thống)
    local function onText(t)
        if type(t) ~= "string" then return end
        local l = string.lower(t)
        if string.find(l, "pirates have been spotted", 1, true) or string.find(l, "raiding castle on the sea", 1, true) then
            armedUntil = tick() + ARM_SECONDS
            if _G.PirateRaidDebug then print("[PirateRaid] Nghe thấy thông báo Pirate Raid") end
        end
    end
    pcall(function()
        local pg = LocalPlayer:WaitForChild("PlayerGui", 10)
        if pg then
            pg.DescendantAdded:Connect(function(d)
                if d:IsA("TextLabel") then
                    onText(d.Text)
                    d:GetPropertyChangedSignal("Text"):Connect(function() onText(d.Text) end)
                end
            end)
        end
    end)
    pcall(function()
        local tcs = game:GetService("TextChatService")
        tcs.MessageReceived:Connect(function(msg) onText(msg.Text) end)
    end)

    local function release()
        _G.PirateRaidBusy = false
        engaged = false
        targetEnemy = nil
        pcall(stopAllFlying)
        pcall(function()
            local c = LocalPlayer.Character
            if c then
                for _, part in ipairs(c:GetChildren()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end)
    end

    local function raidOrFruitBusy()
        return RAID_FIXED.running or RAID_FIXED.starting or autoRaidEnabled or _G.Dungeon
            or _G.BuyMeleeActive == true or _G.FruitPickupBusy == true
            or not Q.SmartController.canRun("pirate")
    end

    local function wanted()
        return _G.PirateRaidFarm and not raidOrFruitBusy()
    end

    _G.MHSpawn(function()
    while task.wait(0.05) do
        if not _G.PirateRaidFarm then
            if engaged or _G.PirateRaidBusy then release() end
            setStatus("Disabled")
        elseif not World3 then
            setStatus("⚠️ Pirate Raid chỉ có ở Sea 3")
        elseif raidOrFruitBusy() then
            if engaged then release() end
            setStatus("Yielding to Raid / fruit collection")
        else
            local ok, err = pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then return end

                local center = castleCenter()
                local list = pirates(center)

                if #list > 0 then
                    lastSeen = tick()
                    if not engaged then engaged = true; _G.PirateRaidBusy = true end

                    -- Mục tiêu: hải tặc gần nhân vật nhất
                    local best, bestD
                    for _, e in ipairs(list) do
                        local d = (e.hrp.Position - hrp.Position).Magnitude
                        if not bestD or d < bestD then best, bestD = e, d end
                    end
                    targetEnemy = best.model  -- Bring Mob & Fast Attack có sẵn dùng làm mục tiêu chính

                    pcall(equipSelectedWeapon)
                    local height = FA.hoverH()
                    local function above() return best.hrp.Position + Vector3.new(0, height, 0) end
                    setStatus(string.format("⚔️ Fighting pirates: %d con còn lại (%s)", #list, best.model.Name))

                    if (hrp.Position - above()).Magnitude > 120 then
                        -- bay THẲNG tới trên đầu mục tiêu
                        _G.FlyStraight(function()
                            return (best.hrp.Parent and best.hum.Health > 0) and above() or nil
                        end, tonumber(_G.PirateRaidSpeed) or 300, function()
                            return wanted() and best.hum.Health > 0
                        end, 25)
                    else
                        -- treo trên đầu mục tiêu (giống các chế độ farm khác)
                        hrp.CFrame = CFrame.new(above())
                        hrp.AssemblyLinearVelocity  = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                        lastHoldPos = above()
                    end

                    if not fastAttackEnabled then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool and not FA.fruitM1(tool, hrp, best.hrp.Position) and not FA.gunM1(tool, hrp, {best})
                            and not FA.isGunTool(tool) then
                            pcall(function() tool:Activate() end)
                        end
                    end

                elseif engaged and tick() - lastSeen < GRACE_SECONDS then
                    -- Hết quái nhưng con "trâu" cuối có thể chưa xuất hiện -> chờ tại chỗ
                    setStatus(string.format("⏳ Chờ con cuối xuất hiện... (%ds)", math.ceil(GRACE_SECONDS - (tick() - lastSeen))))
                    if lastHoldPos then
                        hrp.CFrame = CFrame.new(lastHoldPos)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end

                elseif engaged then
                    release()
                    setStatus("✅ Pirate Raid kết thúc - chờ đợt tiếp theo")

                elseif _G.PirateRaidAutoTravel and tick() < armedUntil then
                    -- Chưa có hải tặc nhưng đã nghe thông báo -> bay sẵn tới lâu đài
                    local dest = center + Vector3.new(0, 60, 0)
                    if (hrp.Position - dest).Magnitude > 150 then
                        _G.PirateRaidBusy = true
                        setStatus("✈️ Pirate Raid sắp bắt đầu - đang bay tới Castle on the Sea...")
                        _G.FlyStraight(function() return dest end, tonumber(_G.PirateRaidSpeed) or 300, function()
                            return wanted() and tick() < armedUntil and #pirates(center) == 0
                        end, 40)
                        _G.PirateRaidBusy = false
                    else
                        setStatus("⏳ Đã tới lâu đài, chờ hải tặc xuất hiện...")
                        hrp.CFrame = CFrame.new(dest)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end

                else
                    setStatus("😴 Chưa có Pirate Raid (cứ 75 phút 1 lần) - đang chờ")
                end
            end)
            if not ok then
                if _G.PirateRaidDebug then warn("[PirateRaid] lỗi:", err) end
                release()
                task.wait(1)
            end
        end
    end
    end) -- task.spawn: vòng lặp chạy nền, không chặn phần còn lại của script
end)()

-- Nút bật/tắt + thẻ trạng thái trên tab Farm
;(function()
    createToggleFeature(farmPage, "AutoPirateRaidToggle", "Auto Pirate Raid",
        "Pirates attack Castle on the Sea (every 75 minutes): travel there automatically, defeat them all, then wait for the final enemy. With Auto Farm enabled, handle the Pirate Raid first and resume farming afterward",
        33, _G.PirateRaidFarm, function(state)
            _G.PirateRaidFarm = state
            if not state then _G.PirateRaidBusy = false end
        end)

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 34)
    card.BackgroundColor3 = BANANA_CARD
    card.LayoutOrder = 34
    card.Parent = farmPage
    addCorner(card, 8)
    addStroke(card, BANANA_CARD_BORDER, 1)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -24, 1, 0)
    txt.Position = UDim2.new(0, 12, 0, 0)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.fromRGB(190, 190, 200)
    txt.TextSize = 11
    txt.Font = Enum.Font.Gotham
    txt.TextWrapped = true
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = card

    _G.MHSpawn(function()
        while txt.Parent do
            txt.Text = "🏴‍☠️ Pirate Raid: " .. tostring(_G.PirateRaidStatus or "-")
            task.wait(0.5)
        end
    end)
end)()

-- VÒNG LẶP CHUYỂN & BAY QUA NHIỀU ĐIỂM FARM MATERIAL KHÁC NHAU (Sea 1 / 2 / 3)
_G.MHSpawn(function()
    while true do
        task.wait(0.05)
        if autoFarmMaterialEnabled then
            pcall(function()
                if not Q.SmartController.canRun("material") then return end -- nhường theo bộ điều phối ưu tiên chung
                -- Chưa hồi sinh xong / đang chết thì chờ, không điều khiển nhân vật cũ
                do
                    local c0 = LocalPlayer.Character
                    local h0 = c0 and c0:FindFirstChildOfClass("Humanoid")
                    if not h0 or h0.Health <= 0 or not c0:FindFirstChild("HumanoidRootPart")
                        or tick() - (Q.lastCharSpawn or 0) < 1.5 then return end
                end
                -- Không farm được (chưa chọn / material không có ở Sea này) -> chỉ thông báo, không bay lung tung
                if not MatFarm.getMobSet() then return end

                equipSelectedWeapon()
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local hrp = character.HumanoidRootPart
                    local heightOffset = FA.hoverH()
                    local enemy = MatFarm.getEnemy()

                    if enemy and enemy:FindFirstChild("HumanoidRootPart") then
                        local enemyHrp = enemy.HumanoidRootPart

                        local targetPos = enemyHrp.Position + Vector3.new(0, heightOffset, 0)
                        local _, yaw, _ = enemyHrp.CFrame:ToOrientation()
                        local targetCFrame = CFrame.new(targetPos) * CFrame.fromOrientation(0, yaw, 0)
                        local distance = (hrp.Position - targetPos).Magnitude

                        -- Quái ở Underwater City mà đang đứng ngoài -> vào thành phố trước
                        if MatFarm.enterIfNeeded(hrp, enemyHrp.Position) then return end

                        if distance > 100 then
                            if not currentFlyTween or targetEnemy ~= enemy then
                                targetEnemy = enemy
                                if currentFlyTween then currentFlyTween:Cancel() end
                                currentFlyTween = TweenService:Create(hrp, TweenInfo.new(distance / flySpeed, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
                                currentFlyTween:Play()
                                do local tw = currentFlyTween; tw.Completed:Connect(function() if currentFlyTween == tw then currentFlyTween = nil end end) end
                            end
                        else
                            if currentFlyTween then currentFlyTween:Cancel(); currentFlyTween = nil end
                            targetEnemy = enemy
                            FA.hoverSet(hrp, targetPos)
                        end
                    else
                        -- Chưa có quái: bay tới các điểm hồi sinh của quái rớt material ở Sea hiện tại
                        local matPosList = MatFarm.getPoints()
                        if #matPosList > 0 then
                            if currentMatPointIndex > #matPosList then
                                currentMatPointIndex = 1
                            end

                            local currentTargetPoint = matPosList[currentMatPointIndex]

                            if MatFarm.enterIfNeeded(hrp, currentTargetPoint) then return end

                            local standPos = currentTargetPoint + Vector3.new(0, heightOffset, 0)
                            local distToMat = (hrp.Position - standPos).Magnitude

                            if distToMat > 15 then
                                if not currentFlyTween or targetEnemy ~= (selectedMaterialTarget .. "_" .. currentMatPointIndex) then
                                    targetEnemy = selectedMaterialTarget .. "_" .. currentMatPointIndex
                                    if currentFlyTween then currentFlyTween:Cancel() end
                                    currentFlyTween = TweenService:Create(hrp, TweenInfo.new(distToMat / flySpeed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(standPos)})
                                    currentFlyTween:Play()
                                    do local tw = currentFlyTween; tw.Completed:Connect(function() if currentFlyTween == tw then currentFlyTween = nil end end) end
                                end
                            else
                                if currentFlyTween then currentFlyTween:Cancel(); currentFlyTween = nil end
                                FA.hoverSet(hrp, standPos)

                                if tick() - lastPointSwitchTime > 2.5 then
                                    lastPointSwitchTime = tick()
                                    currentMatPointIndex = (currentMatPointIndex % #matPosList) + 1
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)
-- ================== SỬA LỖI: BAY TỚI RỒI NHÂN VẬT BỊ RESET, FARM KHÔNG CHẠY LẠI ==================
-- Nguyên nhân phần "farm không chạy": khi nhân vật chết, tween bay (currentFlyTween) và mục tiêu cũ (targetEnemy)
-- vẫn còn trỏ vào nhân vật cũ. Vòng farm thấy "đang có tween / đã đúng mục tiêu" nên KHÔNG tạo tween mới cho
-- nhân vật mới -> đứng yên. Giờ mỗi lần hồi sinh sẽ xoá sạch trạng thái bay & mục tiêu để farm tự chạy lại.
function FA.resetFlightState()
    if currentFlyTween then pcall(function() currentFlyTween:Cancel() end); currentFlyTween = nil end
    if currentRaidTween then pcall(function() currentRaidTween:Cancel() end); currentRaidTween = nil end
    targetEnemy = nil
    EH.hoverBoss = nil; EH.goalPos = nil; EH.holdPos = nil; EH.flyBoss = nil; EH.wasLive = false
    -- Xoá mọi cờ "đang bận" / đang bay còn sót từ nhân vật cũ (nếu không các chức năng sẽ đứng yên sau khi reset)
    submergedTravelBusy = false
    submergedTravelLast = 0
    Q.flyingToGate = false; Q.flyingToExit = false
    Q.gateArriveAt = nil; Q.exitNearAt = nil
    Q.skyEntranceWaitUntil = 0; Q.entranceWaitUntil = 0
    Q.NC = nil
    _G.__FlyN = 0
    _G.FruitPickupBusy = false; _G.PirateRaidBusy = false; _G.EliteBusy = false
    if MatFarm then MatFarm.locked = nil end
    TY.hover = nil; TY.goal = nil; TY.hold = nil; TY.curMob = nil
end

function FA.watchDeath(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    hum.Died:Connect(function()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local pos = hrp and hrp.Position
        FA.resetFlightState()

        -- Chỉ quay lại cổng sau khi chết nếu trước đó đã xác nhận portal/boss.
        -- Nếu chết khi đang farm quái Cake Land thì không tự giả lập trạng thái đã mở cổng.
        if autoFarmEnabled and selectedFarmTarget == "Cake Prince" and World3 and not (Q.DK and Q.DK.on) then
            local hadOpenPortalRun = Q.cakePortalOpen or Q.cakePortalTransitioned or Q.cakeBossSeen or cakePortalEntryAt > 0
            Q.cakePortalTransitioned = false
            Q.cakePortalWaitPos = nil
            Q.cakePortalTransitionedAt = 0
            Q.cakeBossSeenInBossArea = false
            cakePortalEntryAt = 0
            Q.cakeTry = 0
            Q.cakeLastTouch = 0
            Q.cakeGateSince = nil
            Q._cakeBossCache = nil
            if hadOpenPortalRun then
                Q.cakePortalOpen = true
                Q.cakeReturnAfterDeath = true
                isCakePrinceReady = true
                Q.cakeBossSeen = true
                Q.cakeBossSeenAt = tick()
                Q.cakeNeedSummon = false
                Q.cakeLatchUntil = tick() + 180
                cakeStatusText.Text = "💀 Đã chết trong khu boss — hồi sinh xong sẽ quay lại cổng Cake Prince..."
                print("[CakePrince] Người chơi chết trong lượt boss/portal đã xác nhận; sẽ quay lại cổng")
            else
                Q.cakePortalOpen = false
                Q.cakeReturnAfterDeath = false
                Q.cakeBossSeen = false
                isCakePrinceReady = false
                cakeStatusText.Text = "💀 Đã chết khi farm Cake Land — hồi sinh xong tiếp tục farm và kiểm tra cổng."
                print("[CakePrince] Người chơi chết trước khi cổng mở; sẽ tiếp tục farm Cake Land")
            end
        end

        _G.LastDeathInfo = string.format("Chết tại (%.0f, %.0f, %.0f) | farm=%s elite=%s raid=%s",
            pos and pos.X or 0, pos and pos.Y or 0, pos and pos.Z or 0,
            tostring(autoFarmEnabled), tostring(_G.EliteHunter), tostring(autoRaidEnabled))
        print("[AutoFarm]", _G.LastDeathInfo)
    end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    FA.resetFlightState()
    _G.MHSpawn(FA.watchDeath, char)
    -- chờ nhân vật tải xong rồi mới cho vòng farm chạy tiếp (tránh bay khi chưa có HumanoidRootPart)
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.5)
    FA.resetFlightState()
end)
if LocalPlayer.Character then _G.MHSpawn(FA.watchDeath, LocalPlayer.Character) end

-- Chống rơi xuyên map khi đang farm: noclip làm nhân vật mất va chạm nên trọng lực kéo xuống -> rơi khỏi map
-- -> chết ("reset"). Giữ lực đẩy lên (chỉ trục Y) triệt tiêu trọng lực trong lúc bay / treo trên đầu quái.
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local farming = FA.isFarming() or autoChestEnabled or _G.FruitPickupBusy or (_G.__FlyN or 0) > 0 or _G.BuyMeleeActive == true
    local bv = hrp:FindFirstChild("FarmAntiFall")
    if farming then
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "FarmAntiFall"
            bv.MaxForce = Vector3.new(0, 1e6, 0)   -- chỉ giữ trục Y, không cản bay ngang
            bv.Velocity = Vector3.zero
            bv.Parent = hrp
        end

        -- GIỮ NHÂN VẬT ĐỨNG THẲNG: khi cầm Trái Ác Quỷ (đòn trái, knockback, noclip + rơi tự do) nhân vật hay bị
        -- ngã / ragdoll / PlatformStand nên nằm ngang. Mỗi frame: tắt các trạng thái ngã và dựng thẳng lại thân.
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            if FA._stateChar ~= char then
                FA._stateChar = char
                pcall(function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
                end)
            end
            if hum.PlatformStand then hum.PlatformStand = false end
            if hum.Sit then hum.Sit = false end
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll
                or st == Enum.HumanoidStateType.Physics then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end

            local cf = hrp.CFrame
            if cf.UpVector.Y < 0.98 then
                local look = cf.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude < 0.1 then
                    -- đang nằm úp/ngửa: lấy hướng từ vector bên phải
                    local r = cf.RightVector
                    flat = Vector3.new(-r.Z, 0, r.X)
                end
                if flat.Magnitude > 1e-3 then
                    hrp.CFrame = CFrame.lookAt(cf.Position, cf.Position + flat.Unit)
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    elseif bv then
        bv:Destroy()
    end
end)

-- Gọi tay: _G.GoSubmerged() -> tự bay tới Submarine Worker và xuống đảo dưới nước (Sea 3)
_G.GoSubmerged = function()
    if not World3 then
        warn("[GoSubmerged] Only available in Sea 3")
        return
    end
    if getLevel() < 2600 then
        warn("[GoSubmerged] Cần Level 2600 trở lên để đi xuống Submerged Island")
        if Q.SUB and Q.SUB.set then Q.SUB.set("Cần Level 2600 trở lên") end
        return
    end
    if Q.SUB and Q.SUB.force then
        print("[GoSubmerged] Running rồi")
        return
    end
    _G.MHSpawn(function()
        Q.SUB.force = true   -- cho phép bay + noclip kể cả khi Auto Farm đang tắt
        Q.SUB.set("Starting travel to the submerged island (GoSubmerged)")
        local done = false
        for _ = 1, 30 do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                LocalPlayer.CharacterAdded:Wait()
                task.wait(1)
            else
                local okC, stillNeed = pcall(Q.enterIfNeeded, hrp, SUBMERGED_ENTRY_POS)
                if okC and not stillNeed then
                    done = true
                    break
                end
                if not okC then warn("[GoSubmerged] lỗi:", stillNeed) end
                task.wait(1)
            end
        end
        Q.SUB.force = false
        if done then
            Q.SUB.set("Đã xuống đảo dưới nước")
            print("[GoSubmerged] Đã ở Submerged Island")
        else
            warn("[GoSubmerged] Chưa xác nhận được dịch chuyển sau nhiều lần thử. Đứng gần Submarine Worker, kiểm tra hội thoại/Yes rồi chạy _G.DumpSubmarine() để xem log.")
        end
    end)
end

-- Chẩn đoán: in thông tin NPC Submarine Worker, prompt, nút hội thoại
_G.DumpSubmarine = function()
    local w = Q.submergedFindWorker()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    print("[DumpSubmarine] Sea3 =", World3, "| Level =", getLevel(), "| trong đảo =", Q.submergedInside())
    if not w then
        print("[DumpSubmarine] KHÔNG thấy NPC 'Submarine Worker' trong workspace (chưa tải? đứng quá xa?)")
    else
        local pos
        pcall(function() pos = w:IsA("BasePart") and w.Position or w:GetPivot().Position end)
        print("[DumpSubmarine] NPC:", w:GetFullName(), "| pos =", tostring(pos),
              "| khoảng cách =", (root and pos) and math.floor((root.Position - pos).Magnitude) or "?")
        for _, d in ipairs(w:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                print("   ProximityPrompt:", d:GetFullName(), "| Enabled =", d.Enabled, "| Action =", d.ActionText,
                      "| Key =", tostring(d.KeyboardKeyCode), "| Dist =", d.MaxActivationDistance)
            elseif d:IsA("ClickDetector") then
                print("   ClickDetector:", d:GetFullName())
            end
        end
    end
    print("[DumpSubmarine] fireproximityprompt =", typeof(fireproximityprompt), "| firesignal =", typeof(firesignal),
          "| VirtualInputManager =", tostring(okVIM))
    for _, word in ipairs({"yes", "no", "nevermind"}) do
        local btn = Q.submergedFindButton(word)
        print("   nút '" .. word .. "':", btn and btn:GetFullName() or "không thấy")
    end
    print("   câu thoại hiện tại:", Q.submergedDialogText())
end

-- VÒNG LẶP AUTO FARM CHÍNH
_G.MHSpawn(function()
    while true do
        task.wait(0.05)
        if autoFarmEnabled then
            pcall(function()
                if not Q.SmartController.canRun("farm") then return end -- nhường theo bộ điều phối ưu tiên chung
                -- Chưa hồi sinh xong / đang chết thì chờ, không điều khiển nhân vật cũ
                do
                    local c0 = LocalPlayer.Character
                    local h0 = c0 and c0:FindFirstChildOfClass("Humanoid")
                    if not h0 or h0.Health <= 0 or not c0:FindFirstChild("HumanoidRootPart")
                        or tick() - (Q.lastCharSpawn or 0) < 1.5 then return end
                end
                -- Không khóa Auto Farm ở level 2800; nếu level cao hơn, GetQuestData() dùng quest cuối đã khai báo.

                if selectedFarmTarget == "Bones" and not World3 then
                    Q.BonesFarm.setStatus("Chỉ hoạt động ở Sea 3")
                    cancelFarmTween()
                    targetEnemy = nil
                    return
                elseif selectedFarmTarget ~= "Bones" then
                    Q.BonesFarm.setStatus("Disabled")
                end

                equipSelectedWeapon()
                local character = LocalPlayer.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    local hrp = character.HumanoidRootPart

                    -- Nếu game đã dịch chuyển nhân vật khỏi cổng sau khi chạm, chốt trạng thái
                    -- đã vào khu boss. Không được bay ngược về cổng trong lúc chờ boss tải.
                    if selectedFarmTarget == "Cake Prince" and cakePortalEntryAt > 0 then
                        local gateDistance = (hrp.Position - CAKE_PRINCE_GATE_POS).Magnitude
                        if not Q.cakePortalTransitioned and tick() - cakePortalEntryAt <= 60 and gateDistance > 180 then
                            Q.cakePortalTransitioned = true
                            Q.cakePortalOpen = true
                            isCakePrinceReady = true
                            Q.cakeNeedSummon = false
                            Q.cakePortalTransitionedAt = tick()
                            Q.cakePortalWaitPos = hrp.Position
                            Q.cakeLatchUntil = math.max(Q.cakeLatchUntil or 0, tick() + 60)
                            if Q.cakeReturnAfterDeath then
                                -- Đã vào lại khu boss sau hồi sinh; đợi boss stream vào rồi tiếp tục đánh.
                                Q.cakeReturnAfterDeath = false
                                Q.cakeBossSeen = true
                                Q.cakeBossSeenAt = tick()
                                Q.cakeBossSeenInBossArea = false
                                Q.cakeLatchUntil = math.max(Q.cakeLatchUntil or 0, tick() + 150)
                                cakeStatusText.Text = "✅ Đã quay lại khu Cake Prince — đang tìm boss để đánh tiếp..."
                            end
                            print("[CakePrince] Phát hiện đã qua cổng; chờ/tìm boss tại khu vực mới")
                        end
                        if Q.cakePortalTransitioned then
                            Q.cakePortalOpen = true
                            isCakePrinceReady = true
                            -- Nếu khu boss không tải sau thời gian dài, cho phép thử cổng lại thay vì kẹt vô hạn.
                            if not Q.cakeBossSeenInBossArea and tick() - (Q.cakePortalTransitionedAt or 0) > 45 then
                                Q.cakePortalTransitioned = false
                                Q.cakePortalWaitPos = nil
                                Q.cakePortalTransitionedAt = 0
                                Q.cakeBossSeen = false
                                Q.cakeBossSeenAt = 0
                                cakePortalEntryAt = 0
                                Q.cakeTry = 0
                                print("[CakePrince] Chưa tải thấy boss sau 45 giây; thử tiếp cổng Cake Prince")
                            end
                        end
                    end

                    -- QUAN TRỌNG: phải vào Submerged Island TRƯỚC KHI gọi ClaimQuest().
                    -- Nếu nhận quest trước ở Tiki Outpost, quest Submerged không thể nhận được,
                    -- ClaimQuest() trả false và vòng farm return liên tục nên không bao giờ tới bước di chuyển.
                    if selectedFarmTarget == "Auto Level" and World3 and getLevel() >= 2600 then
                        if Q.enterIfNeeded(hrp, SUBMERGED_ENTRY_POS) then
                            return -- đang đi tới NPC / chờ dịch chuyển / thử lại
                        end
                    end

                    if selectedFarmTarget == "Auto Level" then
                        if autoQuestEnabled and not ClaimQuest() then
                            return -- đang nhận quest, đợi xong mới đi farm
                        end
                    elseif selectedFarmTarget == "Cake Prince" and isCakePrinceReady then
                        -- Trạng thái boss/cổng được cập nhật bởi bộ kiểm tra 4 giây; không spam remote ở vòng 0,05 giây.
                    elseif selectedFarmTarget == "Cake Prince" and not isCakePrinceReady then
                        -- Nhận quest để lấy thêm EXP, nhưng nếu GUI quest lỗi thì vẫn tiếp tục hạ quái Cake Land
                        -- vì tiến độ gọi Cake Prince phụ thuộc số quái bị hạ, không nên đứng chờ GUI.
                        if autoQuestEnabled and World3 then Q.ClaimCakeQuest() end
                    elseif selectedFarmTarget == "Bones" then
                        -- Bones rơi từ quái Haunted Castle; không để lỗi nhận quest chặn việc farm vật phẩm.
                        if autoQuestEnabled and World3 then ClaimBonesQuest() end
                    end

                    local enemy = getTargetEnemy()
                    -- Bắt boss ngay trong vòng farm chính (không đợi lần kiểm tra remote 4 giây).
                    if selectedFarmTarget == "Cake Prince" then
                        local liveCakeBoss = Q.FindLiveCakeBoss()
                        if liveCakeBoss then
                            Q.cakePortalOpen = true
                            isCakePrinceReady = true
                            Q.cakeNeedSummon = false
                            EH.cakeLeft = 0
                            Q.cakeBossSeen, Q.cakeBossSeenAt = true, tick()
                            Q.cakeLatchUntil = tick() + 150
                            -- Đang đánh boss: cấm gửi lệnh mở cổng/triệu hồi lại (làm boss reset) và nhớ vị trí boss.
                            Q.cakeSummonBlockUntil = tick() + 120
                            Q.cakeNeedSummon = false
                            do
                                local lbRoot = liveCakeBoss:FindFirstChild("HumanoidRootPart")
                                if lbRoot then Q.cakeLastBossPos = lbRoot.Position end
                            end

                            -- Sau khi cổng được kích hoạt đủ 2 giây, chọn boss làm mục tiêu chính.
                            -- Danh sách Fast Attack bên dưới cũng quét Model lồng bên trong Enemies để không bỏ sót boss.
                            -- Quy trình vẫn là: farm quái đảo bánh -> boss xuất hiện -> vào cổng -> áp sát và đánh boss.
                            local passedGate = Q.cakePortalTransitioned == true
                            if passedGate then
                                enemy = liveCakeBoss
                                if Q.cakePortalTransitioned then Q.cakeBossSeenInBossArea = true end
                                cakeStatusText.Text = string.find(string.lower(liveCakeBoss.Name), "dough king", 1, true)
                                    and "👑 Đã vào khu vực boss — đang farm Dough King!"
                                    or "👑 Đã vào khu vực boss — đang farm Cake Prince!"
                            else
                                enemy = nil
                                cakeStatusText.Text = "🚪 Cake Prince đã xuất hiện — đang bay tới cổng..."
                            end
                        elseif Q.cakeBossSeen and tick() - (Q.cakeBossSeenAt or 0) > 25
                            and not Q.cakeReturnAfterDeath
                            and (not Q.cakePortalTransitioned or Q.cakeBossSeenInBossArea) then
                            -- Chỉ xem là boss đã chết khi đã xác nhận boss ở khu đích;
                            -- model có thể tạm biến mất lúc portal đang chuyển dimension.
                            Q.cakeBossSeen = false
                            Q.cakeLatchUntil = 0
                            Q.cakeNeedSummon = false
                            Q.cakePortalOpen = false
                            isCakePrinceReady = false
                            EH.cakeLeft = nil
                            cakePortalEntryAt = 0
                            Q.cakeTry = 0
                            Q.cakePortalTransitioned = false
                            Q.cakePortalWaitPos = nil
                            Q.cakePortalTransitionedAt = 0
                            Q.cakeBossSeenInBossArea = false
                            Q._cakeBossCache = nil
                            Q.cakeLastBossPos = nil
                            -- Boss thật sự đã chết: chặn gửi lệnh mở cổng ngay lập tức (đợi đủ điều kiện mới).
                            Q.cakeSummonBlockUntil = tick() + 20
                        elseif not isCakePrinceReady and cakePortalEntryAt > 0 and not Q.cakePortalTransitioned then
                            cakePortalEntryAt = 0   -- cổng đóng: lần sau vào cổng lại từ đầu
                            Q.cakeTry = 0
                        end
                    end
                    if selectedFarmTarget == "Bones" then
                        if enemy then
                            Q.BonesFarm.setStatus("Đang đánh: " .. tostring(enemy.Name))
                        else
                            Q.BonesFarm.setStatus("Đang tìm quái / đến điểm hồi sinh")
                        end
                    end

                    -- Từ level 1350, Auto Level đã rời khu ShipQuest. Bỏ qua NPC Thuyền Ma
                    -- còn lưu/stream trên client để chúng không kéo nhân vật quay lại qua cổng.
                    if selectedFarmTarget == "Auto Level" and World2 and getLevel() >= 1350
                        and enemy and enemy:FindFirstChild("HumanoidRootPart")
                        and Q.isCursedShipPosition(enemy.HumanoidRootPart.Position) then
                        enemy = nil
                    end

                    local heightOffset = FA.hoverH()
                    if enemy and enemy:FindFirstChild("HumanoidRootPart") and Q.enterIfNeeded(hrp, enemy.HumanoidRootPart.Position, "main-farm", enemy.Name) then return end
                    
                    if enemy and enemy:FindFirstChild("HumanoidRootPart") then
                        local enemyHrp = enemy.HumanoidRootPart

                        local targetPos = enemyHrp.Position + Vector3.new(0, heightOffset, 0)
                        local _, yaw, _ = enemyHrp.CFrame:ToOrientation()
                        local targetCFrame = CFrame.new(targetPos) * CFrame.fromOrientation(0, yaw, 0)
                        local distance = (hrp.Position - targetPos).Magnitude
                        
                        if distance > 100 then
                            if not currentFlyTween or targetEnemy ~= enemy then
                                targetEnemy = enemy
                                if currentFlyTween then currentFlyTween:Cancel() end
                                currentFlyTween = TweenService:Create(hrp, TweenInfo.new(distance / flySpeed, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
                                currentFlyTween:Play()
                                do local tw = currentFlyTween; tw.Completed:Connect(function() if currentFlyTween == tw then currentFlyTween = nil end end) end
                            end
                        else
                            if currentFlyTween then currentFlyTween:Cancel(); currentFlyTween = nil end
                            targetEnemy = enemy
                            FA.hoverSet(hrp, targetPos)
                        end
                    else
                        -- Đã qua cổng nhưng boss chưa stream vào client: giữ vị trí hiện tại,
                        -- không lặp lại đường bay về cổng Cake Land.
                        if selectedFarmTarget == "Cake Prince" and Q.cakeBossSeen and Q.cakeLastBossPos
                            and tick() - (Q.cakeBossSeenAt or 0) <= 25 and not Q.cakeReturnAfterDeath
                            and (hrp.Position - Q.cakeLastBossPos).Magnitude <= 300 then
                            -- Boss tạm thời mất khỏi client (stream/đổi phase): đứng giữ vị trí cũ của boss,
                            -- KHÔNG quay về cổng/Cake Land để tránh làm hỏng lượt đánh boss.
                            targetEnemy = nil
                            if currentFlyTween then currentFlyTween:Cancel(); currentFlyTween = nil end
                            FA.hoverSet(hrp, Q.cakeLastBossPos + Vector3.new(0, heightOffset, 0))
                            cakeStatusText.Text = "👑 Boss tạm thời mất — đang giữ vị trí chờ boss tải lại..."
                        elseif selectedFarmTarget == "Cake Prince" and Q.cakePortalTransitioned and cakePortalEntryAt > 0 then
                            targetEnemy = nil
                            if currentFlyTween then currentFlyTween:Cancel(); currentFlyTween = nil end
                            local holdPos = Q.cakePortalWaitPos or hrp.Position
                            FA.hoverSet(hrp, holdPos + Vector3.new(0, heightOffset, 0))
                            cakeStatusText.Text = "🚪 Đã qua cổng — đang chờ tải/tìm boss Cake Prince..."
                        else
                        local destinationPos = nil
                        if selectedFarmTarget == "Auto Level" then
                            local qName, qLevel, qMob, qNpcPos, qMobPos = GetQuestData()
                            destinationPos = GetQuestMobSpawn(qMob, qMobPos) or qMobPos or qNpcPos
                        elseif selectedFarmTarget == "Cake Prince" then
                            if isCakePrinceReady then
                                -- Cổng mở: bay tới cổng; tới nơi sẽ liên tục thử chui vào (Q.cakeEnterGate) tới khi boss xuất hiện.
                                destinationPos = CAKE_PRINCE_GATE_POS
                            elseif autoQuestEnabled and World3 then
                                local _, _, cMobName, _, cMobPos = Q.GetCakeQuestData()
                                destinationPos = GetQuestMobSpawn(cMobName, cMobPos) or cMobPos or CAKE_ISLAND_POS
                            else
                                destinationPos = CAKE_ISLAND_POS
                            end
                        elseif selectedFarmTarget == "Bones" then
                            local _, _, bMobName, _, bMobPos = GetHauntedQuestData()
                            destinationPos = GetQuestMobSpawn(bMobName, bMobPos) or bMobPos or HAUNTED_CASTLE_POS
                        elseif selectedFarmTarget == "Farm Boss" and selectedBossTarget ~= "None" then
                            destinationPos = GetQuestMobSpawn(selectedBossTarget, bossSpawnLocations[selectedBossTarget]) or bossSpawnLocations[selectedBossTarget]
                        end

                        -- Chuyển cổng Thuyền Ma do Q.enterIfNeeded xử lý tập trung.
                        -- Không bay tới waypoint có tọa độ nằm bên trong thân tàu sau khi đã thoát.
                        if destinationPos and Q.enterIfNeeded(hrp, destinationPos, "main-farm",
                            selectedFarmTarget == "Farm Boss" and selectedBossTarget or nil) then return end
                        if destinationPos then
                            local cakeGateEntry = selectedFarmTarget == "Cake Prince"
                                and isCakePrinceReady and (destinationPos - CAKE_PRINCE_GATE_POS).Magnitude < 1
                            -- Yêu cầu tải map quanh cổng (StreamingEnabled) để cổng/boss kịp xuất hiện khi bay tới.
                            if cakeGateEntry and tick() - (Q.cakeStreamAt or 0) > 5 then
                                Q.cakeStreamAt = tick()
                                _G.MHSpawn(function()
                                    pcall(function() LocalPlayer:RequestStreamAroundAsync(CAKE_PRINCE_GATE_POS) end)
                                end)
                            end
                            -- Khi cổng mở, bay tới đúng mặt cổng thay vì lơ lửng cao hơn nó.
                            local islandTargetPos = cakeGateEntry
                                and (CAKE_PRINCE_GATE_POS + Vector3.new(0, 1.5, 0))
                                or (destinationPos + Vector3.new(0, heightOffset, 0))
                            local distToIsland = (hrp.Position - islandTargetPos).Magnitude
                            
                            local approachThreshold = cakeGateEntry and 8 or 20
                            if distToIsland > approachThreshold then
                                if not currentFlyTween or targetEnemy ~= selectedFarmTarget then
                                    targetEnemy = selectedFarmTarget
                                    if currentFlyTween then currentFlyTween:Cancel() end
                                    
                                    currentFlyTween = TweenService:Create(hrp, TweenInfo.new(distToIsland / flySpeed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(islandTargetPos)})
                                    currentFlyTween:Play()
                                    
                                    do local tw = currentFlyTween; tw.Completed:Connect(function() if currentFlyTween == tw then currentFlyTween = nil end end) end
                                end
                            else
                                if currentFlyTween then currentFlyTween:Cancel(); currentFlyTween = nil end
                                targetEnemy = selectedFarmTarget
                                if cakeGateEntry then
                                    Q.cakeEnterGate(hrp)
                                else
                                    FA.hoverSet(hrp, islandTargetPos)
                                end
                            end
                        else
                            targetEnemy = nil
                            if currentFlyTween then currentFlyTween:Cancel(); currentFlyTween = nil end
                        end
                        end -- not waiting inside Cake Prince dimension
                    end
                end
            end)
        else
            -- QUAN TRỌNG: lúc Shop đang bay mua võ, Auto Farm đã được tạm tắt.
            -- Không được để vòng lặp này hủy Tween bay tới cổng Underwater City mỗi 0.05 giây.
            -- Chỉ dọn Tween khi không có thao tác mua võ độc lập đang chạy.
            if not autoFarmMaterialEnabled and not autoRaidEnabled and not _G.Dungeon
                and not _G.BuyMeleeActive then
                targetEnemy = nil
                if currentFlyTween then
                    pcall(function() currentFlyTween:Cancel() end)
                    currentFlyTween = nil
                end
            end
        end
    end
end) 


_G.MinhHubLoad(86, "Loading Auto Dough King...")
-- =========================================================
-- AUTO DOUGH KING (Sea 3)
--  Quy trình (theo Blox Fruits Wiki):
--   1) Sweet Chalice = 1 God's Chalice + 10 Conjured Cocoa, đổi ở NPC "Sweet Crafter" (Chocolate Land)
--   2) Đánh đủ 500 quái ở Cake Land (dùng chức năng Cake Prince có sẵn)
--   3) Người đang giữ Sweet Chalice nói chuyện với NPC "drip_mama" -> Dough King xuất hiện
--      (nếu KHÔNG có Sweet Chalice thì drip_mama sẽ gọi Cake Prince thay vì Dough King)
--   4) Đánh Dough King
--  Toàn bộ nằm trong bảng Q.DK để không tốn thêm biến local cấp cao nhất.
-- =========================================================
Q.DK = { on = false, running = false, status = "Disabled", sawBoss = false,
         once = true,          -- true: hạ Dough King xong thì tự tắt
         invAt = 0, inv = { sweet = false, gods = 0, cocoa = 0 },
         lastCraft = 0, lastSummon = 0 }

function Q.DK.setStatus(text)
    Q.DK.status = text
    if Q.DK.label then pcall(function() Q.DK.label.Text = "🍩 Dough King: " .. text end) end
end

function Q.DK.makeUI()
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 40)
    card.BackgroundColor3 = BANANA_CARD
    card.LayoutOrder = 35
    card.Parent = farmPage
    addCorner(card, 8)
    addStroke(card, Color3.fromRGB(255, 170, 0), 1.2)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "🍩 Dough King: Disabled"
    lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = card
    Q.DK.label = lbl
end

-- Quét kho đồ: Sweet Chalice / God's Chalice / Conjured Cocoa
function Q.DK.refreshInv(force)
    if not force and tick() - Q.DK.invAt < 4 then return Q.DK.inv end
    Q.DK.invAt = tick()
    local res = { sweet = false, gods = 0, cocoa = 0 }
    local function scan(c)
        if not c then return end
        for _, t in ipairs(c:GetChildren()) do
            local n = string.lower(t.Name)
            if string.find(n, "sweet chalice", 1, true) then res.sweet = true end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack")); scan(LocalPlayer.Character)
    local commF = getCommF()
    local gotInv = false
    if commF then
        -- Thử tối đa 3 lần: server đôi khi trả nil/rỗng ngay sau khi vừa nhặt/đổi đồ.
        for attempt = 1, 3 do
            local ok, inv = pcall(function() return commF:InvokeServer("getInventory") end)
            if ok and type(inv) == "table" then
                local found = 0
                -- Duyệt đệ quy: chấp nhận cả dạng mảng phẳng lẫn dạng lồng (Materials/Items...),
                -- tên so khớp không phân biệt hoa thường, số lượng đọc từ nhiều tên trường.
                local function walk(t, depth)
                    if depth > 4 then return end
                    for k, it in pairs(t) do
                        if type(it) == "table" then
                            local hasCount = it.Count or it.count or it.Amount or it.Quantity
                            -- Dạng map: inv["Conjured Cocoa"] = {Count = 13} (không có trường Name) -> lấy tên từ key.
                            local nm = it.Name or it.name or it.ItemName or (hasCount and type(k) == "string" and k or nil)
                            if type(nm) == "string" then
                                found = found + 1
                                local n = string.lower((nm:gsub("^%s+", ""):gsub("%s+$", "")))
                                local c = tonumber(it.Count) or tonumber(it.count) or tonumber(it.Amount)
                                    or tonumber(it.Quantity) or tonumber(it.Value) or 1
                                if n == "sweet chalice" then res.sweet = true end
                                if n == "god's chalice" or n == "gods chalice" then res.gods = res.gods + c end
                                if n == "conjured cocoa" then res.cocoa = res.cocoa + c end
                            else
                                walk(it, depth + 1)
                            end
                        elseif type(k) == "string" and type(it) == "number" then
                            -- Dạng map: ["Conjured Cocoa"] = 13
                            local n = string.lower(k)
                            if n == "sweet chalice" and it > 0 then res.sweet = true end
                            if n == "god's chalice" or n == "gods chalice" then res.gods = res.gods + it end
                            if n == "conjured cocoa" then res.cocoa = res.cocoa + it end
                            found = found + 1
                        end
                    end
                end
                walk(inv, 0)
                if found > 0 then gotInv = true; break end
            end
            task.wait(0.3)
        end
    end

    -- Không đọc được kho đồ lần này -> giữ số liệu tốt gần nhất, KHÔNG ghi đè bằng 0
    -- (nguyên nhân hiển thị "Farm Conjured Cocoa 0/10" dù trong túi đã có 13).
    if not gotInv and Q.DK.inv and Q.DK.invGood then
        res.gods = math.max(res.gods, Q.DK.inv.gods or 0)
        res.cocoa = math.max(res.cocoa, Q.DK.inv.cocoa or 0)
        res.sweet = res.sweet or Q.DK.inv.sweet
        Q.DK.invAt = tick() - 3  -- thử đọc lại sớm hơn (sau ~1s)
    elseif gotInv then
        Q.DK.invGood = true
        if res.cocoa == 0 and not Q.DK._dbgPrinted then
            -- Chẩn đoán một lần: in vài tên vật phẩm nhận được để biết server trả dạng gì.
            Q.DK._dbgPrinted = true
            pcall(function()
                local names = {}
                local function dump(t, d)
                    if d > 3 or #names >= 12 then return end
                    for k, it in pairs(t) do
                        if type(it) == "table" then
                            local nm = it.Name or it.name or (type(k) == "string" and k or nil)
                            if nm then names[#names + 1] = tostring(nm) .. "x" .. tostring(it.Count or it.Amount or "?")
                            else dump(it, d + 1) end
                        end
                    end
                end
                dump(commF and commF:InvokeServer("getInventory") or {}, 0)
                print("[DoughKing] Không thấy Conjured Cocoa trong getInventory. Mẫu dữ liệu:", table.concat(names, ", "))
            end)
        end
    end
    Q.DK.inv = res
    return res
end

function Q.DK.findBoss()
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    for _, m in ipairs(enemies:GetChildren()) do
        if string.find(string.lower(m.Name), "dough king", 1, true) then
            local hum = m:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then return m end
        end
    end
    return nil
end

function Q.DK.norm(n) return (string.lower(tostring(n)):gsub("[^%a]", "")) end

function Q.DK.findNpc(frag)
    local enemies = workspace:FindFirstChild("Enemies")
    local function ok(m)
        return m:IsA("Model") and not Players:GetPlayerFromCharacter(m)
            and string.find(Q.DK.norm(m.Name), frag, 1, true)
            and not (enemies and m:IsDescendantOf(enemies))
    end
    local npcs = workspace:FindFirstChild("NPCs")
    if npcs then
        for _, m in ipairs(npcs:GetChildren()) do if ok(m) then return m end end
    end
    for _, m in ipairs(workspace:GetDescendants()) do
        if ok(m) then return m end
    end
    return nil
end

-- Tắt mọi chế độ farm khác + cập nhật ô tick trên menu
function Q.DK.stopFarms()
    for _, nm in ipairs({"AutoFarmTargetToggle", "AutoFarmMaterialToggle", "AutoFarmBossToggle", "AutoRaidToggle", "AutoEliteHunterToggle"}) do
        if toggleUpdateFuncs[nm] then pcall(toggleUpdateFuncs[nm], false) end
    end
    autoFarmEnabled = false
    autoFarmMaterialEnabled = false
    autoRaidEnabled = false
    _G.Dungeon = false
    _G.EliteHunter = false
    _G.EliteBusy = false
end

function Q.DK.farmCake()
    if autoFarmEnabled and selectedFarmTarget == "Cake Prince" and not autoFarmMaterialEnabled and not _G.EliteHunter then return end
    Q.DK.stopFarms()
    selectedFarmTarget = "Cake Prince"
    pcall(function() farmDropdownLabel.Text = "Target: Cake Prince" end)
    autoQuestEnabled = true
    autoFarmEnabled = true
    if toggleUpdateFuncs["AutoFarmTargetToggle"] then pcall(toggleUpdateFuncs["AutoFarmTargetToggle"], true) end
    if toggleUpdateFuncs["AutoQuestToggle"] then pcall(toggleUpdateFuncs["AutoQuestToggle"], true) end
end

function Q.DK.farmCocoa()
    if autoFarmMaterialEnabled and selectedMaterialTarget == "Conjured Cocoa" then return end
    Q.DK.stopFarms()
    selectedMaterialTarget = "Conjured Cocoa"
    pcall(function() materialDropdownLabel.Text = "📦 Material: Conjured Cocoa" end)
    currentMatPointIndex = 1
    autoFarmMaterialEnabled = true
    if toggleUpdateFuncs["AutoFarmMaterialToggle"] then pcall(toggleUpdateFuncs["AutoFarmMaterialToggle"], true) end
end

function Q.DK.farmElite()
    if _G.EliteHunter then return end
    Q.DK.stopFarms()
    _G.EliteHunter = true
    if toggleUpdateFuncs["AutoEliteHunterToggle"] then pcall(toggleUpdateFuncs["AutoEliteHunterToggle"], true) end
end

-- Bay tới NPC rồi nói chuyện, bấm các nút lựa chọn (Yes/Accept/Trade...) cho tới khi stopFn() = true
function Q.DK.talk(npc, words, stopFn, maxSec)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not npc then return false end
    local pos
    pcall(function() pos = npc:IsA("BasePart") and npc.Position or npc:GetPivot().Position end)
    if not pos then return false end

    if (root.Position - pos).Magnitude > 12 then
        pcall(function()
            flyTo(CFrame.new(pos + Vector3.new(0, 3, 0)), math.max(flySpeed, 220), function()
                return Q.DK.on and LocalPlayer.Character ~= nil
            end)
        end)
    end

    Q.submergedOpenDialog(npc)
    local t0, lastClick, lastOpen, lastText, clicked = tick(), 0, tick(), "", false
    while Q.DK.on and tick() - t0 < (maxSec or 15) do
        task.wait(0.3)
        if stopFn() then return true end

        local txt = Q.submergedDialogText()
        if txt ~= "" and txt ~= lastText then
            lastText = txt
            Q.qlog("DoughKing: NPC nói -> " .. txt:sub(1, 90))
        end

        local btn
        for _, w in ipairs(words) do
            btn = Q.submergedFindButton(w)
            if btn then break end
        end
        if btn then
            if tick() - lastClick > 0.8 then
                lastClick = tick()
                clicked = true
                Q.qlog("DoughKing: bấm nút hội thoại")
                Q.submergedClickGui(btn)
            end
        elseif tick() - lastOpen > 2.5 and not clicked then
            lastOpen = tick()
            Q.submergedOpenDialog(npc)
        end
    end
    return clicked
end

-- Đổi God's Chalice + 10 Conjured Cocoa lấy Sweet Chalice ở Sweet Crafter
function Q.DK.craftSweetChalice()
    if tick() - Q.DK.lastCraft < 12 then return end
    Q.DK.lastCraft = tick()
    Q.DK.setStatus("Exchanging for Sweet Chalice at Sweet Crafter")
    local npc = Q.DK.findNpc("sweetcrafter")
    if not npc then
        -- NPC chưa được tải: bay tới Chocolate Land rồi tìm lại
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function()
                flyTo(CFrame.new(Vector3.new(233.22, 60, -12201.23)), math.max(flySpeed, 220), function() return Q.DK.on end)
            end)
        end
        task.wait(1)
        npc = Q.DK.findNpc("sweetcrafter")
    end
    if npc then
        Q.DK.talk(npc, {"yes", "accept", "trade", "craft", "exchange", "okay", "ok"}, function()
            return Q.DK.refreshInv(true).sweet
        end, 18)
    else
        Q.qlog("DoughKing: không tìm thấy NPC Sweet Crafter (Chocolate Land)")
    end
    -- Dự phòng: remote thường dùng cho NPC này
    if not Q.DK.refreshInv(true).sweet then
        local commF = getCommF()
        if commF then pcall(function() commF:InvokeServer("SweetChaliceNpc") end) end
    end
end

-- Nói chuyện với drip_mama (người giữ Sweet Chalice) để triệu hồi Dough King
function Q.DK.summon()
    if tick() - Q.DK.lastSummon < 10 then return end
    Q.DK.lastSummon = tick()
    Q.DK.setStatus("Talking to drip_mama to summon Dough King")
    local npc = Q.DK.findNpc("dripmama")
    if not npc then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function()
                flyTo(CFrame.new(CAKE_PRINCE_GATE_POS + Vector3.new(0, 20, 0)), math.max(flySpeed, 220), function() return Q.DK.on end)
            end)
        end
        task.wait(1)
        npc = Q.DK.findNpc("dripmama")
    end
    if npc then
        Q.DK.talk(npc, {"yes", "accept", "summon", "start", "okay", "ok"}, function()
            return Q.DK.findBoss() ~= nil
        end, 18)
    else
        Q.qlog("DoughKing: không thấy NPC drip_mama")
    end
    -- Dự phòng: remote mở cổng (chỉ có tác dụng khi bạn đang giữ Sweet Chalice)
    if not Q.DK.findBoss() then
        local commF = getCommF()
        if commF then pcall(function() commF:InvokeServer("CakePrinceSpawner", true) end) end
    end
end

function Q.DK.step()
    if not World3 then
        Q.DK.setStatus("Only available in Sea 3")
        return
    end

    -- 4) Dough King đã xuất hiện -> farm/đánh boss (dùng logic Cake Prince có sẵn, nó nhận cả "Dough King")
    local boss = Q.DK.findBoss()
    if boss then
        Q.DK.sawBoss = true
        Q.DK.setStatus("Fighting Dough King")
        Q.DK.farmCake()
        return
    end
    if Q.DK.sawBoss then
        Q.DK.sawBoss = false
        Q.DK.setStatus("Dough King defeated ✅")
        if Q.DK.once then
            Q.DK.on = false
            Q.DK.stopFarms()
            if toggleUpdateFuncs["AutoDoughKingToggle"] then pcall(toggleUpdateFuncs["AutoDoughKingToggle"], false) end
            return
        end
    end

    -- 1) Chưa có Sweet Chalice
    local inv = Q.DK.refreshInv(false)
    if not Q.DK.invGood then
        -- Chưa đọc được kho đồ: thử lại vài lần, nếu vẫn không được thì KHÔNG kẹt mãi ở đây.
        Q.DK.invFail = (Q.DK.invFail or 0) + 1
        if Q.DK.invFail <= 3 then
            Q.DK.setStatus("Đang đọc kho đồ... (" .. Q.DK.invFail .. "/3)")
            Q.DK.invAt = 0
            return
        end
        Q.DK.invUnknown = true
    else
        Q.DK.invFail = 0
        Q.DK.invUnknown = false
    end
    -- Không đọc được số vật liệu: thử đổi Sweet Chalice thẳng ở NPC (server tự kiểm tra đủ đồ chưa),
    -- mỗi 90 giây một lần; không đủ thì đi farm tiếp như bình thường.
    if Q.DK.invUnknown and not inv.sweet and tick() - (Q.DK.lastBlindCraft or 0) > 90 then
        Q.DK.lastBlindCraft = tick()
        Q.DK.stopFarms()
        Q.DK.setStatus("Không đọc được kho đồ — thử đổi Sweet Chalice trực tiếp")
        Q.DK.craftSweetChalice()
        return
    end
    if not inv.sweet then
        if inv.gods >= 1 and inv.cocoa >= 10 then
            Q.DK.stopFarms()
            Q.DK.craftSweetChalice()
        elseif inv.cocoa < 10 then
            Q.DK.setStatus(("Farm Conjured Cocoa %d/10"):format(inv.cocoa))
            Q.DK.farmCocoa()
        else
            Q.DK.setStatus("Missing God's Chalice -> running Elite Hunter to obtain one")
            Q.DK.farmElite()
        end
        return
    end

    -- 2) Có Sweet Chalice: đủ 500 quái chưa?
    if isCakePrinceReady then
        Q.DK.stopFarms()
        Q.DK.summon()      -- 3) nói chuyện drip_mama
    else
        local left = EH.cakeLeft
        Q.DK.setStatus(left and ("Farm Cake Land: còn " .. left .. "/500 quái") or "Farming Cake Land (counting 500 mobs)")
        Q.DK.farmCake()
    end
end

function Q.DK.loop()
    if Q.DK.running then return end
    Q.DK.running = true
    while Q.DK.on do
        task.wait(1.5)
        local okRun, err = pcall(Q.DK.step)
        if not okRun then Q.qlog("DoughKing: lỗi", tostring(err)) end
    end
    Q.DK.running = false
    if Q.DK.status ~= "Dough King defeated ✅" then Q.DK.setStatus("Disabled") end
end

-- (Đã bỏ thẻ trạng thái "Dough King: ..." trên menu; trạng thái vẫn hiện ở thẻ "Farming" đầu tab.)

-- Kiểm tra đủ nguyên liệu triệu hồi Dough King:
--   Cần Sweet Chalice (hoặc God's Chalice x1 + Conjured Cocoa x10 để đổi) và đủ 500 quái Cake Land.
function Q.DK.checkMaterials()
    local inv = Q.DK.refreshInv(true)
    local ready, msg
    if inv.sweet then
        ready, msg = true, "Đã có Sweet Chalice — đủ nguyên liệu triệu hồi Dough King"
    elseif inv.gods >= 1 and inv.cocoa >= 10 then
        ready, msg = true, ("Đủ nguyên liệu đổi Sweet Chalice (God's Chalice %d, Conjured Cocoa %d/10)"):format(inv.gods, inv.cocoa)
    else
        local lack = {}
        if inv.gods < 1 then lack[#lack + 1] = "thiếu God's Chalice (0/1)" end
        if inv.cocoa < 10 then lack[#lack + 1] = ("thiếu Conjured Cocoa (%d/10)"):format(inv.cocoa) end
        ready, msg = false, "CHƯA đủ nguyên liệu: " .. table.concat(lack, ", ")
    end
    print("[DoughKing] " .. msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Dough King", Text = msg, Duration = 8,
        })
    end)
    return ready, msg
end
_G.CheckDoughKing = function() return Q.DK.checkMaterials() end

createToggleFeature(farmPage, "AutoDoughKingToggle", "Auto Dough King",
    "Complete the Sweet Chalice task → defeat 500 mobs in Cake Land → talk to drip_mama → defeat Dough King (Sea 3)",
    32, false, function(state)
    Q.DK.on = state
    if state then
        if not World3 then
            Q.DK.setStatus("Only available in Sea 3")
        end
        Q.DK.sawBoss = false
        Q.DK.invAt = 0
        _G.MHSpawn(function() pcall(Q.DK.checkMaterials) end)
        _G.MHSpawn(Q.DK.loop)
    else
        Q.DK.setStatus("Disabled")
    end
end)

-- Gọi tay: _G.DoughKing(true/false)
_G.DoughKing = function(on)
    if toggleUpdateFuncs["AutoDoughKingToggle"] then pcall(toggleUpdateFuncs["AutoDoughKingToggle"], on ~= false) end
    Q.DK.on = (on ~= false)
    if Q.DK.on then _G.MHSpawn(Q.DK.loop) end
end

-- =========================================================
-- AUTO SABER (Sea 1) — tự làm chuỗi nhiệm vụ lấy kiếm Saber:
--   1) Jungle: giẫm 5 nút (plates)      2) Phòng đố Jungle: lấy đuốc (Torch)
--   3) Desert: đốt cửa gỗ bằng đuốc     4) Desert: lấy cốc (Cup)
--   5) Frozen Village: hứng nước vào cốc, đưa cho Sick Man
--   6) Pirate Village: nói chuyện Rich Man -> đánh Mob Leader -> nhận Relic
--   7) Jungle: đặt Relic vào cửa bí mật -> đánh Saber Expert -> nhận Saber
-- Tiến trình lấy từ server: CommF_:InvokeServer("ProQuestProgress") (bảng
-- UsedTorch / UsedCup / TalkedSon / KilledMob / UsedRelic). Nếu server không trả
-- bảng này, script tự dò theo vật phẩm trong túi (Torch / Cup / Relic).
-- Mọi bước đều ghi log "[Saber]" ở F9 để dễ chỉnh khi game đổi.
-- =========================================================
Q.SB = { on = false, running = false, status = "Disabled", lastStage = "", plateAt = 0, plated = false,
         lastTry = {}, bossAt = 0 }

function Q.SB.setStatus(t)
    Q.SB.status = t
end
function Q.SB.log(...)
    print("[Saber]", ...)
    pcall(Q.qlog, "Saber:", ...)
end

function Q.SB.root()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

-- Nhật ký tối đa mỗi `gap` giây cho mỗi khoá, tránh spam khi bước chạy lặp.
function Q.SB.every(key, gap)
    local now = tick()
    if now - (Q.SB.lastTry[key] or 0) < gap then return false end
    Q.SB.lastTry[key] = now
    return true
end

function Q.SB.fly(pos, sp)
    local root = Q.SB.root()
    if not root then return false end
    if typeof(pos) == "CFrame" then pos = pos.Position end
    if (root.Position - pos).Magnitude <= 8 then return true end
    pcall(function()
        flyTo(CFrame.new(pos), math.max(flySpeed or 190, sp or 220), function()
            return Q.SB.on and LocalPlayer.Character ~= nil
        end)
    end)
    return true
end

function Q.SB.progress()
    local commF = getCommF()
    if not commF then return nil end
    local ok, p = pcall(function() return commF:InvokeServer("ProQuestProgress") end)
    if ok and type(p) == "table" then return p end
    return nil
end

function Q.SB.hasTool(frag)
    frag = string.lower(frag)
    local function scan(c)
        if not c then return nil end
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and string.find(string.lower(t.Name), frag, 1, true) then return t end
        end
    end
    return scan(LocalPlayer:FindFirstChild("Backpack")) or scan(LocalPlayer.Character)
end

function Q.SB.equip(tool)
    local _, hum = Q.SB.root()
    if tool and hum and tool.Parent ~= LocalPlayer.Character then pcall(function() hum:EquipTool(tool) end) end
end

-- Đã có Saber chưa (túi / nhân vật / kho đồ server)
function Q.SB.hasSaber()
    if Q.SB.hasTool("saber") then
        local t = Q.SB.hasTool("saber")
        if t and not string.find(string.lower(t.Name), "expert", 1, true) then return true end
    end
    local commF = getCommF()
    if commF then
        local ok, inv = pcall(function() return commF:InvokeServer("getInventory") end)
        if ok and type(inv) == "table" then
            local found = false
            local function walk(t, d)
                if d > 3 or found then return end
                for k, it in pairs(t) do
                    if type(it) == "table" then
                        local nm = it.Name or it.name or (type(k) == "string" and k or nil)
                        if type(nm) == "string" and string.lower(nm) == "saber" then found = true return end
                        walk(it, d + 1)
                    end
                end
            end
            walk(inv, 0)
            return found
        end
    end
    return false
end

-- Tìm Part/Model theo từ khoá tên trong một khu vực (mặc định workspace.Map)
function Q.SB.findAll(patterns, scope)
    local out = {}
    local root = scope or workspace:FindFirstChild("Map") or workspace
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Model") then
            local n = string.lower(d.Name)
            for _, p in ipairs(patterns) do
                if string.find(n, p, 1, true) then out[#out + 1] = d break end
            end
        end
    end
    return out
end

function Q.SB.posOf(o)
    if o:IsA("BasePart") then return o.Position end
    local ok, cf = pcall(function() return o:GetPivot() end)
    return ok and cf.Position or nil
end

-- Chạm / kích hoạt một đối tượng: firetouchinterest + ProximityPrompt + ClickDetector
function Q.SB.activate(o)
    local root = Q.SB.root()
    if not root or not o then return end
    local parts = {}
    if o:IsA("BasePart") then parts[1] = o end
    for _, d in ipairs(o:GetDescendants()) do
        if d:IsA("BasePart") and #parts < 6 then parts[#parts + 1] = d end
    end
    for _, p in ipairs(parts) do
        if typeof(firetouchinterest) == "function" then
            pcall(function() firetouchinterest(root, p, 0); task.wait(0.05); firetouchinterest(root, p, 1) end)
        end
    end
    for _, d in ipairs(o:GetDescendants()) do
        if d:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
            pcall(function() d.HoldDuration = 0; fireproximityprompt(d) end)
        elseif d:IsA("ClickDetector") and typeof(fireclickdetector) == "function" then
            pcall(function() fireclickdetector(d) end)
        end
    end
end

-- Bay tới đối tượng rồi kích hoạt. Trả về true nếu đã tới nơi.
function Q.SB.goAndActivate(o, hold)
    local pos = Q.SB.posOf(o)
    if not pos then return false end
    Q.SB.fly(pos + Vector3.new(0, 3, 0))
    Q.SB.activate(o)
    task.wait(hold or 0.6)
    return true
end

-- Nói chuyện NPC (không phụ thuộc Q.DK.on). Bấm các nút hội thoại phù hợp tới khi stopFn() hoặc hết giờ.
function Q.SB.talk(npc, words, stopFn, maxSec)
    local pos = Q.SB.posOf(npc)
    if not pos then return false end
    Q.SB.fly(pos + Vector3.new(0, 3, 0))
    pcall(Q.submergedOpenDialog, npc)
    local t0, lastClick, lastOpen, clicked = tick(), 0, tick(), false
    while Q.SB.on and tick() - t0 < (maxSec or 12) do
        task.wait(0.3)
        if stopFn and stopFn() then return true end
        local btn
        for _, w in ipairs(words) do
            local okB, b = pcall(Q.submergedFindButton, w)
            if okB and b then btn = b break end
        end
        if btn then
            if tick() - lastClick > 0.8 then
                lastClick = tick(); clicked = true
                pcall(Q.submergedClickGui, btn)
            end
        elseif tick() - lastOpen > 2.5 and not clicked then
            lastOpen = tick()
            pcall(Q.submergedOpenDialog, npc)
        end
    end
    return clicked
end

-- Gọi remote quest, thử lần lượt các biến thể tên; trả về kết quả đầu tiên khác nil
function Q.SB.invoke(variants)
    local commF = getCommF()
    if not commF then return nil end
    for _, args in ipairs(variants) do
        local ok, r = pcall(function() return commF:InvokeServer(table.unpack(args)) end)
        Q.SB.log("remote", table.concat((function() local t = {} for i, a in ipairs(args) do t[i] = tostring(a) end return t end)(), ","), "->", tostring(r))
        if ok and r ~= nil then return r end
    end
    return nil
end

-- ---------- Từng bước ----------

-- 1) Giẫm các nút ở Jungle
function Q.SB.doPlates()
    Q.SB.setStatus("Jungle: giẫm các nút (plates)")
    local jungle = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Jungle")
    local plates = {}
    if jungle then
        local qp = jungle:FindFirstChild("QuestPlates")
        local scope = qp or jungle
        for _, o in ipairs(Q.SB.findAll({"plate", "button"}, scope)) do
            if o:IsA("BasePart") then plates[#plates + 1] = o end
        end
    end
    if #plates == 0 then
        Q.SB.log("không thấy plates trong Map.Jungle (có thể chưa tải) — bay tới giữa Jungle")
        Q.SB.fly(Vector3.new(-1250, 40, 360))
        return false
    end
    for _, p in ipairs(plates) do
        if not Q.SB.on then return false end
        Q.SB.goAndActivate(p, 0.7)
    end
    Q.SB.plated = true
    return true
end

-- 2) Lấy đuốc trong phòng đố Jungle
function Q.SB.doTorch()
    -- Đuốc CHỈ hợp lệ khi nhặt ở phòng đố Jungle (người dùng xác nhận toạ độ). Không gọi remote từ xa.
    local TORCH = Vector3.new(-1679.05, 20.55, 170.33)
    Q.SB.setStatus("Jungle: nhặt đuốc ở phòng đố")
    local root = Q.SB.root()
    if not root then return false end

    if (root.Position - TORCH).Magnitude > 6 then
        Q.SB.torchAt = nil
        Q.SB.fly(TORCH)
        -- tween bỏ qua khi <=10 stud nên đặt thẳng vào điểm đứng
        local r2 = Q.SB.root()
        if r2 and (r2.Position - TORCH).Magnitude < 16 then
            pcall(function() r2.CFrame = CFrame.new(TORCH) * (r2.CFrame - r2.CFrame.Position) end)
            r2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        return false
    end

    -- Đã tới điểm nhặt đuốc: đứng yên, kích hoạt mọi đối tượng "torch" trong 15 stud
    Q.SB.torchAt = Q.SB.torchAt or tick()
    for _, d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("BasePart") or d:IsA("Model")) and string.find(string.lower(d.Name), "torch", 1, true)
            and not (LocalPlayer.Character and d:IsDescendantOf(LocalPlayer.Character))
            and not d:IsDescendantOf(LocalPlayer) then
            local pos = Q.SB.posOf(d)
            if pos and (pos - TORCH).Magnitude <= 15 then Q.SB.activate(d) end
        end
    end
    if Q.SB.every("torchLog", 20) then
        Q.SB.log("đang đứng ở điểm nhặt đuốc; có tool torch =", tostring(Q.SB.hasTool("torch") ~= nil))
    end
    -- Nhặt đuốc bằng cách đi tới sát tường: đứng đủ 3 giây rồi coi như xong
    if tick() - Q.SB.torchAt >= 3 and Q.SB.hasTool("torch") then
        Q.SB.torchOk = true
        Q.SB.log("đã nhặt đuốc ở phòng đố")
        return true
    end
    return false
end

-- 3) Đốt cửa gỗ ở Desert bằng đuốc
-- Chẩn đoán cửa gỗ + đuốc: in ra F9 và tự copy vào clipboard (nếu executor hỗ trợ) để gửi cho dev.
function Q.SB.dumpDoor(tool, near)
    local out = {"=== SABER DOOR DEBUG ==="}
    local function add(t) out[#out + 1] = t end
    local p = Q.SB.progress()
    if p then
        local kv = {}
        for k, v in pairs(p) do kv[#kv + 1] = tostring(k) .. "=" .. tostring(v) end
        add("ProQuestProgress: " .. table.concat(kv, ", "))
    else
        add("ProQuestProgress: (không trả bảng)")
    end
    add("Torch tool: " .. tostring(tool and tool.Name) .. " | Parent=" .. tostring(tool and tool.Parent and tool.Parent.Name)
        .. " | RequiresHandle=" .. tostring(tool and tool.RequiresHandle) .. " | ToolTip=" .. tostring(tool and tool.ToolTip))
    if tool then
        local n = 0
        for _, d in ipairs(tool:GetDescendants()) do
            n = n + 1
            if n > 25 then break end
            add("  tool> " .. d.ClassName .. " " .. d.Name)
        end
        local attrs = {}
        for k, v in pairs(tool:GetAttributes()) do attrs[#attrs + 1] = tostring(k) .. "=" .. tostring(v) end
        if #attrs > 0 then add("  tool attrs: " .. table.concat(attrs, ", ")) end
    end
    local root = Q.SB.root()
    add("Vị trí nhân vật: " .. (root and tostring(root.Position) or "?"))
    local n = 0
    for _, d in ipairs(near) do
        n = n + 1
        if n > 40 then break end
        local kids = {}
        for _, c in ipairs(d:GetChildren()) do kids[#kids + 1] = c.ClassName end
        add(("  part> %s [%s] parent=%s collide=%s transp=%s mat=%s pos=%s kids=%s"):format(
            d.Name, d.ClassName, tostring(d.Parent and d.Parent.Name), tostring(d.CanCollide),
            tostring(d.Transparency), tostring(d.Material), tostring(d.Position), table.concat(kids, "/")))
    end
    local text = table.concat(out, "\n")
    print(text)
    if typeof(setclipboard) == "function" then
        pcall(function() setclipboard(text) end)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Auto Saber", Text = "Đã copy log cửa gỗ vào clipboard — dán gửi dev", Duration = 8 })
        end)
    end
end

function Q.SB.doBurn()
    Q.SB.setStatus("Desert: đốt cửa gỗ bằng đuốc")
    local tool = Q.SB.hasTool("torch")
    if not tool then return end
    Q.SB.equip(tool)

    -- Vị trí cửa gỗ cần đốt (do người dùng xác nhận bằng ảnh + toạ độ).
    -- DOOR = đúng điểm đứng của người chơi trước cửa (toạ độ nhân vật), nên bay thẳng tới đó, không cộng thêm độ cao.
    local DOOR = Vector3.new(1122.85, -0.08, 4388.49)
    local root = Q.SB.root()
    if not root then return end
    if (root.Position - DOOR).Magnitude > 14 then
        Q.SB.setStatus("Desert: bay tới cửa gỗ để đốt")
        -- Bay tới gần rồi đặt chính xác vào điểm đứng (tween bỏ qua khoảng cách <=10 nên đặt CFrame trực tiếp)
        Q.SB.fly(DOOR + Vector3.new(0, 6, 0))
        local r2 = Q.SB.root()
        if r2 and (r2.Position - DOOR).Magnitude < 14 then
            pcall(function() r2.CFrame = CFrame.new(DOOR) * (r2.CFrame - r2.CFrame.Position) end)
            r2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        return
    end

    -- Chỉ gọi remote thử tối đa mỗi 20 giây (tránh spam server)
    if Q.SB.every("burnRemote", 25) then
        -- Thử nhiều tên lệnh có thể dùng cho bước đốt cửa; kết quả nào khác nil được ghi log "[Saber] remote ..."
        local names = {"DrinkTorch", "UseTorch", "BurnDoor", "DesertBurn", "Torch", "Burn", "TorchDoor", "UseTorchDoor", "PlaceTorch"}
        local variants = {}
        for _, n in ipairs(names) do variants[#variants + 1] = {"ProQuestProgress", n} end
        Q.SB.invoke(variants)
    end

    -- Quét vị trí đứng quanh cửa (mỗi lượt một vị trí) vì đuốc có thể chỉ cháy ở đúng điểm chạm
    Q.SB.burnIdx = (Q.SB.burnIdx or 0) % 9 + 1
    local OFFS = {Vector3.new(0, 0, 0), Vector3.new(-2, 0, 0), Vector3.new(2, 0, 0), Vector3.new(0, 0, -2), Vector3.new(0, 0, 2),
                  Vector3.new(0, 0, -4), Vector3.new(0, 0, 4), Vector3.new(-4, 0, 0), Vector3.new(4, 0, 0)}
    pcall(function()
        local r = Q.SB.root()
        if r then
            r.CFrame = CFrame.new(DOOR + OFFS[Q.SB.burnIdx]) * (r.CFrame - r.CFrame.Position)
            r.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end)

    -- Kích hoạt mọi ProximityPrompt / ClickDetector trong 25 stud quanh cửa (toàn workspace, không chỉ Map)
    if Q.SB.every("burnPrompts", 5) then
        local cnt = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
                local par = d.Parent
                local pos = par and (par:IsA("BasePart") and par.Position or (par:IsA("Attachment") and par.WorldPosition))
                if pos and (pos - DOOR).Magnitude <= 25 then
                    cnt = cnt + 1
                    Q.SB.log("kích hoạt", d.ClassName, d.Name, "trên", par.Name, "action=" .. tostring(d.ClassName == "ProximityPrompt" and d.ActionText or ""))
                    if d:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                        pcall(function() d.HoldDuration = 0; fireproximityprompt(d) end)
                    elseif typeof(fireclickdetector) == "function" then
                        pcall(function() fireclickdetector(d) end)
                    end
                end
            end
        end
        if cnt == 0 then Q.SB.log("không có ProximityPrompt/ClickDetector nào trong 25 stud quanh cửa") end
    end

    -- Gửi phím tương tác thông dụng (E/F) nếu cửa dùng ProximityPrompt kiểu phím
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        for _, key in ipairs({Enum.KeyCode.E, Enum.KeyCode.F}) do
            vim:SendKeyEvent(true, key, false, game); task.wait(0.05); vim:SendKeyEvent(false, key, false, game)
        end
    end)

    -- Liệt kê các Part quanh cửa (bán kính 20 stud) để chạm bằng đuốc + ghi log tên để chỉnh sau.
    local near, names, seen = {}, {}, {}
    local mapF = workspace:FindFirstChild("Map") or workspace
    for _, d in ipairs(mapF:GetDescendants()) do
        if d:IsA("BasePart") and (d.Position - DOOR).Magnitude <= 20 then
            near[#near + 1] = d
            local key = d.Name .. "/" .. tostring(d.Parent and d.Parent.Name)
            if not seen[key] and #names < 15 then seen[key] = true; names[#names + 1] = key end
        end
    end
    if Q.SB.every("burnNames", 30) then
        Q.SB.log("Part gần cửa gỗ:", table.concat(names, ", "))
    end

    -- Quay mặt về phía cửa: lấy Part gần tâm cửa nhất (ưu tiên tên burn/door/wood/fire)
    local face, fd = nil, math.huge
    for _, d in ipairs(near) do
        local n = string.lower(d.Name)
        local bonus = (string.find(n, "burn", 1, true) or string.find(n, "door", 1, true)
            or string.find(n, "wood", 1, true) or string.find(n, "fire", 1, true)) and 8 or 0
        local dist = (d.Position - DOOR).Magnitude - bonus
        if dist < fd then face, fd = d, dist end
    end
    if face then
        pcall(function()
            local flat = Vector3.new(face.Position.X, root.Position.Y, face.Position.Z)
            if (flat - root.Position).Magnitude > 0.5 then root.CFrame = CFrame.lookAt(root.Position, flat) end
        end)
    end

    -- Dùng đuốc: Activate + chạm Handle vào từng Part quanh cửa + kích hoạt prompt/click
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
    if Q.SB.every("burnDump", 60) then Q.SB.dumpDoor(tool, near) end

    -- (a) Bắn mọi Remote nằm trong chính cây đuốc (nếu đuốc có script riêng)
    if Q.SB.every("burnToolRemotes", 15) then
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("RemoteEvent") then pcall(function() d:FireServer() end)
            elseif d:IsA("RemoteFunction") then pcall(function() d:InvokeServer() end) end
        end
    end
    -- (b) Đi bộ ép sát vào cửa (đuốc cần chạm vật lý thật)
    pcall(function()
        local _, hum = Q.SB.root()
        if hum and face then hum:MoveTo(face.Position) end
    end)
    -- (c) Click chuột thật qua VirtualInputManager (kích Tool.Activated giống người chơi)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
        vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 1)
        task.wait(0.15)
        vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 1)
    end)
    pcall(function() tool:Activate() end)
    for _, d in ipairs(near) do
        if handle and typeof(firetouchinterest) == "function" then
            pcall(function() firetouchinterest(handle, d, 0); firetouchinterest(handle, d, 1) end)
        end
        for _, c in ipairs(d:GetChildren()) do
            if c:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                pcall(function() c.HoldDuration = 0; fireproximityprompt(c) end)
            elseif c:IsA("ClickDetector") and typeof(fireclickdetector) == "function" then
                pcall(function() fireclickdetector(c) end)
            end
        end
    end
    -- Giả lập click chuột (tool có thể cần Activate bằng chuột thật)
    pcall(function()
        if VirtualUser then
            VirtualUser:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VirtualUser:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end
    end)
    task.wait(1.2)
end

-- 4) Lấy cốc ở Desert
function Q.SB.doCup()
    Q.SB.setStatus("Desert: lấy cốc (Cup)")
    if Q.SB.hasTool("cup") then return true end
    Q.SB.invoke({ {"ProQuestProgress", "GetCup"} })
    if Q.SB.hasTool("cup") then return true end
    local desert = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Desert")
    local cands = desert and Q.SB.findAll({"cup"}, desert) or {}
    for _, o in ipairs(cands) do
        if Q.SB.goAndActivate(o, 0.8) and Q.SB.hasTool("cup") then return true end
    end
    return Q.SB.hasTool("cup") ~= nil
end

-- 5) Hứng nước ở Frozen Village rồi đưa cho Sick Man
function Q.SB.doWaterAndSickMan()
    local cup = Q.SB.hasTool("cup")
    if cup then
        Q.SB.equip(cup)
        Q.SB.setStatus("Frozen Village: hứng nước vào cốc")
        Q.SB.invoke({ {"ProQuestProgress", "FillCup", cup}, {"ProQuestProgress", "FillCup"} })
        local frozen = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Frozen")
        for _, o in ipairs(frozen and Q.SB.findAll({"drip", "water", "stalactite"}, frozen) or {}) do
            Q.SB.goAndActivate(o, 1.2)
        end
    end
    Q.SB.setStatus("Frozen Village: đưa cốc cho Sick Man")
    Q.SB.invoke({ {"ProQuestProgress", "SickMan"} })
    local npc = Q.DK.findNpc("sickman") or Q.DK.findNpc("sick")
    if npc then
        Q.SB.talk(npc, {"help", "yes", "accept", "ok"}, nil, 10)
    else
        Q.SB.fly(Vector3.new(1100, 120, -1250))
    end
end

-- 6) Rich Man (Pirate Village): lần 1 nghe kể bị cướp, lần 2 sau khi diệt Mob Leader thì nhận Relic
function Q.SB.doRichMan()
    Q.SB.setStatus("Pirate Village: nói chuyện Rich Man")
    Q.SB.invoke({ {"ProQuestProgress", "RichSon"} })
    local npc = Q.DK.findNpc("richman") or Q.DK.findNpc("rich")
    if npc then
        Q.SB.talk(npc, {"yes", "ok", "accept", "help"}, nil, 10)
    else
        Q.SB.fly(Vector3.new(-1150, 25, 3850))
    end
end

-- Đánh boss bằng vòng Auto Farm Boss có sẵn
function Q.SB.fightBoss(name)
    if _G.EliteHunter then Q.DK.stopFarms() end
    if selectedBossTarget ~= name or selectedFarmTarget ~= "Farm Boss" or not autoFarmEnabled then
        Q.DK.stopFarms()
        selectedBossTarget = name
        selectedFarmTarget = "Farm Boss"
        pcall(function() bossDropdownLabel.Text = "👑 Boss: " .. name end)
        autoFarmEnabled = true
        Q.SB.log("bật Auto Farm Boss ->", name)
    end
end

function Q.SB.stopBoss()
    if selectedFarmTarget == "Farm Boss" and autoFarmEnabled then
        autoFarmEnabled = false
        if toggleUpdateFuncs["AutoFarmBossToggle"] then pcall(toggleUpdateFuncs["AutoFarmBossToggle"], false) end
    end
end

-- 7) Đặt Relic vào cửa bí mật ở Jungle
function Q.SB.relicTool()
    return Q.SB.hasTool("relic") or Q.SB.hasTool("cross") or Q.SB.hasTool("key")
end

function Q.SB.doRelic()
    -- Cửa bí mật có hình chữ thập (người dùng xác nhận toạ độ + ảnh), cạnh phòng Saber Expert.
    local DOOR = Vector3.new(-1460.58, 42.45, 47.87)
    Q.SB.setStatus("Jungle: đặt Relic mở cửa bí mật")
    local relic = Q.SB.relicTool()
    if relic then Q.SB.equip(relic) end
    local root = Q.SB.root()
    if not root then return end

    if (root.Position - DOOR).Magnitude > 8 then
        Q.SB.fly(DOOR)
        local r2 = Q.SB.root()
        if r2 and (r2.Position - DOOR).Magnitude < 16 then
            pcall(function() r2.CFrame = CFrame.new(DOOR) * (r2.CFrame - r2.CFrame.Position) end)
            r2.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        return
    end

    if Q.SB.every("relicRemote", 15) then
        Q.SB.invoke({ {"ProQuestProgress", "PlaceRelic"} })
    end

    -- Kích hoạt mọi prompt/click/part có tên liên quan trong 20 stud quanh cửa
    local handle = relic and (relic:FindFirstChild("Handle") or relic:FindFirstChildWhichIsA("BasePart"))
    local root2 = Q.SB.root()
    for _, d in ipairs(workspace:GetDescendants()) do
        local isP = d:IsA("ProximityPrompt") or d:IsA("ClickDetector")
        if isP or d:IsA("BasePart") then
            local par = isP and d.Parent or d
            local pos = par and par:IsA("BasePart") and par.Position
            if pos and (pos - DOOR).Magnitude <= 20 and not (LocalPlayer.Character and d:IsDescendantOf(LocalPlayer.Character)) then
                if d:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                    pcall(function() d.HoldDuration = 0; fireproximityprompt(d) end)
                elseif d:IsA("ClickDetector") and typeof(fireclickdetector) == "function" then
                    pcall(function() fireclickdetector(d) end)
                elseif d:IsA("BasePart") and handle and typeof(firetouchinterest) == "function" then
                    pcall(function() firetouchinterest(handle, d, 0); firetouchinterest(handle, d, 1) end)
                end
            end
        end
    end
    if relic then pcall(function() relic:Activate() end) end
    if Q.SB.every("relicLog", 20) then Q.SB.log("đang đặt Relic tại cửa bí mật; tool =", tostring(relic and relic.Name)) end
    task.wait(1)
end

function Q.SB.finish(msg)
    Q.SB.setStatus(msg)
    Q.SB.log(msg)
    Q.SB.stopBoss()
    Q.SB.on = false
    if toggleUpdateFuncs["AutoSaberToggle"] then pcall(toggleUpdateFuncs["AutoSaberToggle"], false) end
end

function Q.SB.step()
    if not World1 then Q.SB.setStatus("Chỉ có ở Sea 1 (First Sea)") return end
    local lv = 0
    pcall(function() lv = LocalPlayer.Data.Level.Value end)
    if lv > 0 and lv < 200 then Q.SB.setStatus("Cần Lv 200+ (hiện Lv " .. lv .. ")") return end
    if Q.SB.hasSaber() then Q.SB.finish("Đã có Saber ✅") return end

    local p = Q.SB.progress()
    local stage
    if p then
        if not p.UsedTorch then stage = "torch"
        elseif not p.UsedCup then stage = "cup"
        elseif not p.TalkedSon then stage = "rich1"
        elseif not p.KilledMob then stage = "mob"
        elseif not p.UsedRelic then stage = "relic"
        else stage = "boss" end
    else
        -- Không có bảng tiến trình: suy ra từ vật phẩm trong túi
        if Q.SB.relicTool() then stage = "relic"
        elseif Q.SB.hasTool("cup") then stage = "cup"
        elseif Q.SB.hasTool("torch") then stage = "torch"
        else stage = "torch" end
    end
    if stage ~= Q.SB.lastStage then
        Q.SB.lastStage = stage
        local dump = {}
        if p then for k, v in pairs(p) do dump[#dump + 1] = tostring(k) .. "=" .. tostring(v) end end
        Q.SB.log("giai đoạn:", stage, "| tiến trình:", table.concat(dump, ", "))
    end

    if stage ~= "mob" and stage ~= "boss" then Q.SB.stopBoss() end

    if stage == "torch" then
        if not (Q.SB.torchOk and Q.SB.hasTool("torch")) then
            Q.SB.torchOk = false
            if not Q.SB.plated then Q.SB.doPlates() end
            Q.SB.doTorch()
        else
            Q.SB.doBurn()
        end
    elseif stage == "cup" then
        if not Q.SB.hasTool("cup") then Q.SB.doCup() else Q.SB.doWaterAndSickMan() end
    elseif stage == "rich1" then
        Q.SB.doRichMan()
    elseif stage == "mob" then
        Q.SB.setStatus("Đánh Mob Leader (Lv 120)")
        Q.SB.fightBoss("Mob Leader")
    elseif stage == "relic" then
        if not Q.SB.relicTool() then
            Q.SB.stopBoss()
            Q.SB.doRichMan()   -- lần 2: nhận Relic
        end
        if Q.SB.relicTool() then Q.SB.doRelic() end
    else
        Q.SB.setStatus("Đánh Saber Expert (Lv 200)")
        Q.SB.fightBoss("Saber Expert")
    end
end

function Q.SB.loop()
    if Q.SB.running then return end
    Q.SB.running = true
    while Q.SB.on do
        task.wait(1.5)
        local ok, err = pcall(Q.SB.step)
        if not ok then Q.SB.log("lỗi:", tostring(err)) end
    end
    Q.SB.running = false
    if Q.SB.status ~= "Đã có Saber ✅" then Q.SB.setStatus("Disabled") end
end

createToggleFeature(farmPage, "AutoSaberToggle", "Auto Saber",
    "Sea 1: tự làm chuỗi nhiệm vụ Saber (plates Jungle → đuốc → cốc nước → Rich Man → Saber Expert)",
    33, false, function(state)
    Q.SB.on = state
    if state then
        Q.SB.lastStage = ""
        _G.MHSpawn(Q.SB.loop)
    else
        Q.SB.stopBoss()
        Q.SB.setStatus("Disabled")
    end
end)

_G.AutoSaber = function(on)
    if toggleUpdateFuncs["AutoSaberToggle"] then pcall(toggleUpdateFuncs["AutoSaberToggle"], on ~= false) end
    Q.SB.on = (on ~= false)
    if Q.SB.on then _G.MHSpawn(Q.SB.loop) end
end

-- =========================================================
-- HIỆN TRẠNG THÁI XUỐNG ĐẢO DƯỚI NƯỚC (SEA 3)
-- Thẻ trạng thái trong tab Auto Farm, tự cập nhật theo từng bước:
--   bay tới NPC -> nói chuyện (bước 1/2, 2/2) -> bấm Yes -> xuống đảo
-- Không tốn biến local cấp cao nhất: mọi thứ nằm trong Q.SUB.
-- =========================================================
Q.SUB = { step = "Not started", lastChange = 0, tries = 0 }

function Q.SUB.set(text)
    if Q.SUB.step ~= text then
        Q.SUB.step = text
        Q.SUB.lastChange = tick()
    end
end

-- Nghe các dòng log "Submerged: ..." đã có sẵn để biết đang ở bước nào
Q.SUB.origLog = Q.qlog
Q.qlog = function(...)
    local first = ...
    if type(first) == "string" then
        local lower = string.lower(first)
        if string.sub(first, 1, 10) == "Submerged:" then
            local n = string.match(first, "lần (%d+)")
            if n then
                Q.SUB.tries = tonumber(n) or Q.SUB.tries
                Q.SUB.set("Đang bay tới Submarine Worker (lần " .. n .. ")")
            elseif string.find(lower, "đang nói chuyện", 1, true) then
                Q.SUB.set("Đang nói chuyện với Submarine Worker")
            elseif string.find(lower, "npc nói", 1, true) then
                if string.find(lower, "ride", 1, true) or string.find(lower, "homeland", 1, true) then
                    Q.SUB.set("Bước 2/2: NPC hỏi \"Want to take a ride?\" -> chọn Yes")
                else
                    Q.SUB.set("Bước 1/2: NPC đang nói -> chọn Yes")
                end
            elseif string.find(lower, "bấm yes", 1, true) then
                Q.SUB.set("Đã bấm Yes, chờ game chuyển xuống đảo...")
            elseif string.find(lower, "đang gọi rf/submarineworkerspeak", 1, true) then
                Q.SUB.set("Đang gửi lệnh xuống Submerged Island...")
            elseif string.find(lower, "remote đã phản hồi", 1, true) then
                Q.SUB.set("Đã nhận phản hồi, đang kiểm tra vị trí...")
            elseif string.find(lower, "npc từ chối", 1, true) then
                Q.SUB.set("NPC từ chối: kiểm tra điều kiện mở khóa đảo")
            elseif string.find(lower, "xác nhận đã xuống", 1, true) then
                Q.SUB.set("Đã xuống đảo dưới nước")
            elseif string.find(lower, "chưa thấy npc", 1, true) then
                Q.SUB.set("Chưa thấy NPC Submarine Worker (đứng quá xa?)")
            elseif string.find(lower, "chưa xác nhận", 1, true) or string.find(lower, "chưa gọi được", 1, true) then
                Q.SUB.set("Chưa xuống được, đang thử lại...")
            end
        end
    end
    return Q.SUB.origLog(...)
end

-- =========================================================
-- THẺ "ĐANG FARM GÌ" (đầu tab Auto Farm)
-- Dòng 1: chế độ đang chạy + quest/nguyên liệu/boss
-- Dòng 2: mục tiêu hiện tại (tên quái, % máu, khoảng cách) + level + vị trí
-- =========================================================
Q.FS = {}

function Q.FS.mode()
    if _G.FruitPickupBusy then return "🍎 Đang nhặt trái ác quỷ", Color3.fromRGB(255, 215, 0) end
    if _G.PirateRaidBusy then return "🏴‍☠️ Đang đánh Pirate Raid (Sea 3)", Color3.fromRGB(255, 120, 80) end
    if Q.DK and Q.DK.on then
        return "🍩 Auto Dough King: " .. tostring(Q.DK.status), Color3.fromRGB(255, 180, 60)
    end
    if Q.SB and Q.SB.on then
        return "⚔️ Auto Saber: " .. tostring(Q.SB.status), Color3.fromRGB(120, 200, 255)
    end
    if _G.EliteHunter then return "👹 Elite Hunter: " .. tostring(EH.status), Color3.fromRGB(255, 120, 80) end
    if _G.TyrantFarm or _G.TyrantSummon then
        return "🦅 Tyrant of the Skies: " .. tostring(TY.status), Color3.fromRGB(255, 120, 80)
    end
    if _G.Dungeon or autoRaidEnabled then return "🌀 Running Raid", Color3.fromRGB(180, 120, 255) end
    if autoChestEnabled then return "📦 Đang farm Chest (Beli/Bạc/Vàng)", Color3.fromRGB(255, 215, 0) end
    if autoFarmMaterialEnabled then
        local mat = (selectedMaterialTarget ~= "" and selectedMaterialTarget) or "chưa chọn"
        return "📦 Farm Material: " .. mat, Color3.fromRGB(90, 200, 255)
    end
    if autoFarmEnabled then
        local t = selectedFarmTarget
        if t == "Auto Level" then
            local info = "Auto Level"
            local okQ, qName, qLevel, qMob = pcall(GetQuestData)
            if okQ and qMob then
                info = ("Auto Level | Quái: %s | Quest: %s"):format(tostring(qMob), tostring(qName))
                if Q.lastCur and Q.lastTotal then
                    info = info .. (" (%d/%d)"):format(Q.lastCur, Q.lastTotal)
                end
            end
            return "⚔️ " .. info, Color3.fromRGB(90, 225, 125)
        elseif t == "Cake Prince" then
            local left = EH.cakeLeft
            local extra = (left == nil and "") or (left == 0 and " | Cổng đã mở" or (" | còn " .. left .. "/500 quái"))
            return "🎂 Farm Cake Prince" .. extra, Color3.fromRGB(255, 170, 0)
        elseif t == "Bones" then
            local step = Q.BonesFarm and Q.BonesFarm.status or "Đang tìm quái"
            return "💀 Farm Bones (Haunted Castle) | " .. tostring(step), Color3.fromRGB(200, 200, 220)
        elseif t == "Farm Boss" then
            local b = (selectedBossTarget ~= "" and selectedBossTarget) or "chưa chọn"
            return "👑 Farm Boss: " .. b, Color3.fromRGB(255, 120, 80)
        end
        return "⚔️ Farm: " .. tostring(t), Color3.fromRGB(90, 225, 125)
    end
    return "⏸ Không farm gì (tất cả đang tắt)", Color3.fromRGB(170, 170, 180)
end

function Q.FS.target()
    local parts = {}
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local e = targetEnemy
    if typeof(e) == "Instance" and e.Parent then
        local hum = e:FindFirstChildOfClass("Humanoid")
        local name = string.gsub(e.Name, "%s*%[.-%]%s*$", "")
        local line = "Mục tiêu: " .. name
        if hum and hum.MaxHealth > 0 then
            line = line .. (" (%d%% máu)"):format(math.floor(hum.Health / hum.MaxHealth * 100 + 0.5))
        end
        local er = e:FindFirstChild("HumanoidRootPart")
        if er and root then
            line = line .. (" | cách %d studs"):format(math.floor((er.Position - root.Position).Magnitude))
        end
        table.insert(parts, line)
    elseif type(e) == "string" and e ~= "" then
        table.insert(parts, "Đang bay tới: " .. e)
    else
        table.insert(parts, "Target: none (searching for mobs / moving)")
    end
    table.insert(parts, "Lv." .. tostring(getLevel()))
    local where
    if World3 and Q.submergedInside() then where = "Đảo dưới nước"
    elseif World1 then where = "Sea 1" elseif World2 then where = "Sea 2" else where = "Sea 3" end
    table.insert(parts, where)
    return table.concat(parts, " | ")
end

function Q.FS.makeUI()
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 58)
    card.BackgroundColor3 = BANANA_CARD
    card.LayoutOrder = -1
    card.Parent = farmPage
    addCorner(card, 8)
    addStroke(card, Color3.fromRGB(90, 225, 125), 1.2)

    local l1 = Instance.new("TextLabel")
    l1.Size = UDim2.new(1, -24, 0, 30)
    l1.Position = UDim2.new(0, 12, 0, 4)
    l1.BackgroundTransparency = 1
    l1.TextSize = 13
    l1.Font = Enum.Font.GothamBold
    l1.TextXAlignment = Enum.TextXAlignment.Left
    l1.TextYAlignment = Enum.TextYAlignment.Center
    l1.TextWrapped = true
    l1.TextColor3 = Color3.fromRGB(255, 215, 0)
    l1.Text = "Farming: ..."
    l1.Parent = card

    local l2 = Instance.new("TextLabel")
    l2.Size = UDim2.new(1, -24, 0, 20)
    l2.Position = UDim2.new(0, 12, 0, 34)
    l2.BackgroundTransparency = 1
    l2.TextSize = 11
    l2.Font = Enum.Font.Gotham
    l2.TextXAlignment = Enum.TextXAlignment.Left
    l2.TextWrapped = true
    l2.TextColor3 = Color3.fromRGB(190, 190, 205)
    l2.Text = ""
    l2.Parent = card

    Q.FS.l1, Q.FS.l2 = l1, l2
end

Q.FS.makeUI()
_G.MHSpawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            if not Q.FS.l1 then return end
            local text, color = Q.FS.mode()
            Q.FS.l1.Text = "Farming: " .. text
            Q.FS.l1.TextColor3 = color
            Q.FS.l2.Text = Q.FS.target()
        end)
    end
end)

_G.MinhHubLoad(90, "Loading Auto Start...")
-- =========================================================
-- AUTO START: tự xuống đảo dưới nước (Sea 3) rồi farm level
-- Đặt Q.AUTO_SUBMERGED_FARM = false nếu không muốn tự chạy khi load script.
-- Level < 2600: farm quest bình thường; tới 2600+ Auto Level tự bay tới
-- Submarine Worker, bấm Yes (2 bước) rồi farm quái dưới nước.
-- =========================================================
Q.AUTO_SUBMERGED_FARM = false   -- false: KHÔNG tự bật Auto Farm Level khi load script

_G.MHSpawn(function()
    if not Q.AUTO_SUBMERGED_FARM or not World3 then return end

    repeat
        task.wait(1)
        local ch = LocalPlayer.Character
    until game:IsLoaded() and ch and ch:FindFirstChild("HumanoidRootPart") and LocalPlayer:FindFirstChild("Data")
    task.wait(3)

    selectedFarmTarget = "Auto Level"
    autoQuestEnabled = true
    autoFarmMaterialEnabled = false
    autoRaidEnabled = false
    _G.Dungeon = false
    autoFarmEnabled = true

    -- cập nhật hình ô tick trên menu
    pcall(function()
        if toggleUpdateFuncs["AutoQuestToggle"] then toggleUpdateFuncs["AutoQuestToggle"](true) end
        if toggleUpdateFuncs["AutoFarmTargetToggle"] then toggleUpdateFuncs["AutoFarmTargetToggle"](true) end
    end)

    Q.qlog("AUTO START: Auto Level + Auto Quest đã bật, level hiện tại", getLevel())
    if getLevel() >= 2600 then
        Q.qlog("AUTO START: level >= 2600 -> sẽ tự xuống đảo dưới nước")
    end
end)


_G.MinhHubLoad(94, "Loading 3D interface...")
-- =========================================================
-- GIAO DIỆN REDZ 3D
--  * Bóng đổ nhiều lớp dưới cửa sổ (đồng bộ vị trí/kích thước khi kéo, thu nhỏ, mở/đóng)
--  * Mỗi thẻ/nút/ô tick có lớp "gloss": sáng ở trên, tối ở dưới -> nổi khối
--  * Nhấn nút: đảo chiều ánh sáng (cảm giác lún xuống)
--  * Tab đang chọn: tấm đỏ nổi; đường sáng đỏ dưới tiêu đề
--  Mọi thứ nằm trong Q.UI3D (không tốn thêm biến local cấp cao nhất).
-- =========================================================
Q.UI3D = { shadows = {}, spread = {4, 9, 15}, alpha = {0.90, 0.93, 0.96} }

function Q.UI3D.gloss(obj, radius, topA, botA)
    if not obj or obj:FindFirstChild("Gloss3D") then return nil end
    local g = Instance.new("Frame")
    g.Name = "Gloss3D"
    g.Size = UDim2.new(1, 0, 1, 0)
    g.BackgroundColor3 = Color3.new(1, 1, 1)
    g.BorderSizePixel = 0
    g.Active = false
    g.ZIndex = 0
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = g
    local grad = Instance.new("UIGradient")
    grad.Rotation = 90
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 120, 128)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
    })
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, topA or 0.76),
        NumberSequenceKeypoint.new(0.22, 0.92),
        NumberSequenceKeypoint.new(0.62, 0.95),
        NumberSequenceKeypoint.new(1, botA or 0.52),
    })
    grad.Parent = g
    g.Parent = obj
    return g
end

function Q.UI3D.press(btn, glossParent)
    local g = glossParent and glossParent:FindFirstChild("Gloss3D")
    local grad = g and g:FindFirstChildOfClass("UIGradient")
    if not grad or not btn:IsA("GuiButton") then return end
    btn.MouseButton1Down:Connect(function() grad.Rotation = 270 end)   -- ánh sáng đảo chiều = nút lún
    btn.MouseButton1Up:Connect(function() grad.Rotation = 90 end)
    btn.MouseLeave:Connect(function() grad.Rotation = 90 end)
end

function Q.UI3D.radiusOf(obj, default)
    local c = obj:FindFirstChildOfClass("UICorner")
    return c and c.CornerRadius.Offset or default
end

function Q.UI3D.skin(obj)
    if obj:FindFirstChild("Gloss3D") then return end
    if obj.Name == "Gloss3D" or obj.Name == "Plate3D" then return end
    if obj:IsA("Frame") then
        if obj.BackgroundTransparency >= 0.95 then return end
        local par = obj.Parent
        local sz = obj.Size
        if par and par:IsA("ScrollingFrame") and sz.Y.Offset >= 24 then
            Q.UI3D.gloss(obj, Q.UI3D.radiusOf(obj, 8))                   -- thẻ chức năng
            -- nút bấm trong suốt phủ thẻ: ép hiệu ứng lún cho cả thẻ
            for _, ch in ipairs(obj:GetChildren()) do
                if ch:IsA("TextButton") and ch.BackgroundTransparency >= 0.95 then Q.UI3D.press(ch, obj) end
            end
            obj.ChildAdded:Connect(function(ch)
                if ch:IsA("TextButton") and ch.BackgroundTransparency >= 0.95 then Q.UI3D.press(ch, obj) end
            end)
        elseif sz.X.Offset == 20 and sz.Y.Offset == 20 then
            Q.UI3D.gloss(obj, 5, 0.6, 0.45)                              -- ô tick
        end
    elseif obj:IsA("TextButton") or obj:IsA("TextBox") then
        if obj.BackgroundTransparency < 0.95 then
            Q.UI3D.gloss(obj, Q.UI3D.radiusOf(obj, 6), 0.8, 0.6)
            Q.UI3D.press(obj, obj)
        end
    end
end

function Q.UI3D.syncShadow()
    local P, S = mainFrame.Position, mainFrame.Size
    for i, sh in ipairs(Q.UI3D.shadows) do
        local e = Q.UI3D.spread[i]
        sh.Position = UDim2.new(P.X.Scale, P.X.Offset - e, P.Y.Scale, P.Y.Offset - e + 8)
        sh.Size = UDim2.new(S.X.Scale, S.X.Offset + e * 2, S.Y.Scale, S.Y.Offset + e * 2)
        sh.Visible = mainFrame.Visible
    end
end

function Q.UI3D.init()
    -- 1) bóng đổ nhiều lớp
    for i = 1, 3 do
        local sh = Instance.new("Frame")
        sh.Name = "Shadow3D_" .. i
        sh.BackgroundColor3 = Color3.new(0, 0, 0)
        sh.BackgroundTransparency = Q.UI3D.alpha[i]
        sh.BorderSizePixel = 0
        sh.Active = false
        sh.ZIndex = 0
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 12 + Q.UI3D.spread[i])
        c.Parent = sh
        local sc = Instance.new("UIScale")
        sc.Name = "ShadowScale"
        sc.Parent = sh
        sh.Parent = screenGui
        Q.UI3D.shadows[i] = sh
    end
    Q.UI3D.syncShadow()
    for _, prop in ipairs({"Position", "Size", "Visible"}) do
        mainFrame:GetPropertyChangedSignal(prop):Connect(Q.UI3D.syncShadow)
    end
    local ms = mainFrame:FindFirstChild("MenuScale")
    if ms then
        ms:GetPropertyChangedSignal("Scale"):Connect(function()
            for _, sh in ipairs(Q.UI3D.shadows) do sh.ShadowScale.Scale = ms.Scale end
        end)
    end

    -- 2) tiêu đề: đường sáng đỏ + chiều sâu
    Q.UI3D.gloss(header, 12, 0.82, 0.55)
    local hl = header:FindFirstChild("HeaderLine")
    if hl then
        hl.Size = UDim2.new(1, 0, 0, 2)
        hl.Position = UDim2.new(0, 0, 1, -2)
        hl.BackgroundColor3 = BANANA_YELLOW
        local g = Instance.new("UIGradient")
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        g.Parent = hl
    end
    local sg = Instance.new("UIGradient")        -- thanh bên tối dần xuống dưới
    sg.Rotation = 90
    sg.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 156))
    sg.Parent = sidebar

    -- 3) nút thu nhỏ / đóng / nút nổi mở menu
    for _, b in ipairs({closeBtn, minimizeBtn}) do
        Q.UI3D.gloss(b, 8, 0.7, 0.5)
        Q.UI3D.press(b, b)
    end
    Q.UI3D.gloss(toggleBtn, 28, 0.62, 0.4)
    Q.UI3D.press(toggleBtn, toggleBtn)

    -- 4) tab đang chọn = tấm đỏ nổi khối
    for _, data in pairs(tabs) do
        local plate = Instance.new("Frame")
        plate.Name = "Plate3D"
        plate.Size = UDim2.new(1, 14, 1, 0)
        plate.Position = UDim2.new(0, -14, 0, 0)
        plate.BackgroundColor3 = Color3.new(1, 1, 1)
        plate.BorderSizePixel = 0
        plate.Active = false
        plate.ZIndex = 0
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = plate
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new(Color3.fromRGB(255, 96, 108), Color3.fromRGB(150, 22, 34))
        g.Parent = plate
        local st = Instance.new("UIStroke")
        st.Color = Color3.fromRGB(255, 140, 150)
        st.Transparency = 0.55
        st.Thickness = 1
        st.Parent = plate
        plate.Visible = data.Page.Visible
        plate.Parent = data.Button
        data.Page:GetPropertyChangedSignal("Visible"):Connect(function()
            plate.Visible = data.Page.Visible
        end)
    end

    -- 5) toàn bộ thẻ / ô tick / nút / ô nhập hiện có + sau này tạo thêm
    local function skinLater(o)
        task.defer(function()
            if o.Parent then pcall(Q.UI3D.skin, o) end
        end)
    end
    for _, o in ipairs(pagesFolder:GetDescendants()) do Q.UI3D.skin(o) end
    pagesFolder.DescendantAdded:Connect(skinLater)
    -- hộp chọn (dropdown) nằm ngoài pagesFolder
    mainFrame.DescendantAdded:Connect(function(o)
        if o:IsA("TextButton") or o:IsA("TextBox") then skinLater(o) end
    end)
end

function Q.UI3D.run()
    do return end   -- giao diện mới phẳng, bán trong suốt: không áp lớp bóng 3D
    local okSkin, errSkin = pcall(Q.UI3D.init)
    if not okSkin then warn("[UI3D] Bỏ qua giao diện 3D do lỗi:", errSkin) end
end
Q.UI3D.run()

_G.MinhHubLoad(97, "Loading Status tab...")
-- =========================================================
--   TAB STATUS: QUÉT THÔNG TIN SERVER (thời gian, người chơi, ping/FPS,
--   sự kiện đảo, boss, trái trên đất, tiến độ Elite / Cake Prince)
-- =========================================================
do
    local okSt, errSt = pcall(function()
        local Stats = game:GetService("Stats")
        local Lighting = game:GetService("Lighting")
        local statusPage = createTab("Status", "", false)

        local rows = {}
        local order = 0
        local function nextOrder() order += 1 return order end

        local function section(text)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 22)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.TextSize = 13
            lbl.Font = Enum.Font.GothamBold
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.LayoutOrder = nextOrder()
            lbl.Parent = statusPage
        end

        local function info(key, title)
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 46)
            card.BackgroundColor3 = BANANA_CARD
            card.BackgroundTransparency = 0.35
            card.LayoutOrder = nextOrder()
            card.Parent = statusPage
            addCorner(card, 6)
            local st = addStroke(card, BANANA_CARD_BORDER, 1)
            st.Transparency = 0.7

            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, -20, 0, 20)
            t.Position = UDim2.new(0, 10, 0, 5)
            t.BackgroundTransparency = 1
            t.Text = title
            t.TextColor3 = Color3.fromRGB(235, 237, 245)
            t.TextSize = 12
            t.Font = Enum.Font.GothamMedium
            t.TextXAlignment = Enum.TextXAlignment.Left
            t.Parent = card

            local v = Instance.new("TextLabel")
            v.Size = UDim2.new(1, -20, 0, 16)
            v.Position = UDim2.new(0, 10, 0, 25)
            v.BackgroundTransparency = 1
            v.Text = "Scanning..."
            v.TextColor3 = Color3.fromRGB(140, 146, 160)
            v.TextSize = 10
            v.Font = Enum.Font.Gotham
            v.TextXAlignment = Enum.TextXAlignment.Left
            v.TextTruncate = Enum.TextTruncate.AtEnd
            v.Parent = card
            rows[key] = v
        end

        local function setv(key, text, good)
            local v = rows[key]
            if not v then return end
            v.Text = text
            v.TextColor3 = good and Color3.fromRGB(110, 200, 255) or Color3.fromRGB(140, 146, 160)
        end

        section("Server Stats")
        info("time",    "Server Time")
        info("players", "Players")
        info("net",     "Ping / FPS")
        info("sea",     "Sea & Night")
        info("moon",    "Moon")
        section("Server Events")
        info("events",  "Đảo sự kiện (Mirage / Prehistoric / Kitsune)")
        info("fruits",  "Trái ác quỷ trên đất")
        info("bosses",  "Boss đang xuất hiện")
        section("Local Stats")
        info("elite",   "Elite Progress")
        info("cake",    "Cake Prince")
        info("me",      "Nhân vật (Level / Beli / Fragments)")

        -- FPS trung bình
        local fps, acc, frames = 60, 0, 0
        RunService.Heartbeat:Connect(function(dt)
            acc += dt frames += 1
            if acc >= 1 then fps = math.floor(frames / acc + 0.5) acc, frames = 0, 0 end
        end)

        local function fmtTime(sec)
            sec = math.floor(sec)
            return string.format("%dh %dm %ds", sec // 3600, (sec % 3600) // 60, sec % 60)
        end

        local function findIn(parentList, names)
            for _, par in ipairs(parentList) do
                for _, nm in ipairs(names) do
                    local o = par and par:FindFirstChild(nm)
                    if o then return o end
                end
            end
            return nil
        end

        local BOSS_LIST = {
            {"Rip Indra", {"rip_indra", "rip_indra True Form"}},
            {"Dough King", {"Dough King"}},
            {"Cake Prince", {"Cake Prince"}},
            {"Darkbeard", {"Darkbeard"}},
            {"Soul Reaper", {"Soul Reaper"}},
            {"Order (Law)", {"Order"}},
            {"Diablo (Elite)", {"Diablo"}},
            {"Urban (Elite)", {"Urban"}},
            {"Deandre (Elite)", {"Deandre"}},
        }

        local function scanLight()
            setv("time", fmtTime(workspace.DistributedGameTime) .. "  (server uptime)", true)

            local plrs = Players:GetPlayers()
            setv("players", string.format("%d / %d người chơi", #plrs, Players.MaxPlayers), true)

            local ping = "?"
            pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms" end)
            setv("net", "Ping " .. ping .. "   |   FPS " .. fps, true)

            local clock = Lighting.ClockTime
            local night = clock >= 18 or clock < 5.5
            setv("sea", string.format("Sea %d   |   %s (%.1fh)", World1 and 1 or (World2 and 2 or 3), night and "Night" or "Day", clock), night)

            local moonTxt = "Unknown"
            pcall(function()
                local sky = Lighting:FindFirstChildOfClass("Sky")
                local id = sky and tostring(sky.MoonTextureId):match("%d+")
                if id then
                    if id == "9709149431" then moonTxt = "🌕 FULL MOON"
                    else moonTxt = "Not a full moon (ID " .. id .. ")" end
                end
            end)
            setv("moon", moonTxt, string.find(moonTxt, "TRÒN") ~= nil)

            -- thông tin nhân vật
            local data = LocalPlayer:FindFirstChild("Data")
            local function dv(n) local o = data and data:FindFirstChild(n) return o and o.Value or "?" end
            setv("me", string.format("Level %s  |  Beli %s  |  Fragments %s", tostring(dv("Level")), tostring(dv("Beli")), tostring(dv("Fragments"))), true)
        end

        local function scanHeavy()
            -- Đảo sự kiện
            local locs = workspace:FindFirstChild("_WorldOrigin") and workspace._WorldOrigin:FindFirstChild("Locations")
            local map = workspace:FindFirstChild("Map")
            local ev = {}
            for _, e in ipairs({
                {"Mirage Island", {"MysticIsland", "Mirage Island"}},
                {"Prehistoric Island", {"PrehistoricIsland", "Prehistoric Island"}},
                {"Kitsune Island", {"KitsuneIsland", "Kitsune Island"}},
                {"Frozen Dimension", {"FrozenDimension", "Frozen Dimension"}},
            }) do
                if findIn({locs, map, workspace}, e[2]) then ev[#ev + 1] = "✔ " .. e[1] end
            end
            setv("events", #ev > 0 and table.concat(ev, "   ") or "No event islands currently exist", #ev > 0)

            -- Trái trên đất (chỉ xét con trực tiếp của workspace cho nhẹ)
            local fr = {}
            for _, o in ipairs(workspace:GetChildren()) do
                if o:IsA("Tool") and string.find(o.Name, "Fruit", 1, true) then
                    fr[#fr + 1] = (o.Name:gsub("%s*Fruit%s*", ""))
                end
            end
            setv("fruits", #fr > 0 and (#fr .. " fruits: " .. table.concat(fr, ", ")) or "No fruits on the ground", #fr > 0)

            -- Boss xuất hiện trong workspace.Enemies
            local enemies = workspace:FindFirstChild("Enemies")
            local bs = {}
            if enemies then
                for _, b in ipairs(BOSS_LIST) do
                    for _, nm in ipairs(b[2]) do
                        local m = enemies:FindFirstChild(nm)
                        local h = m and m:FindFirstChildOfClass("Humanoid")
                        if m and h and h.Health > 0 then bs[#bs + 1] = b[1] break end
                    end
                end
            end
            setv("bosses", #bs > 0 and table.concat(bs, ", ") or "No bosses currently spawned", #bs > 0)

            -- Cake Prince
            if World3 then
                setv("cake", EH and EH.cakeLeft and ("Còn " .. tostring(EH.cakeLeft) .. " / 500 mobs") or "No data yet (open the Boss tab and wait a few seconds)", EH and EH.cakeLeft ~= nil)
            else
                setv("cake", "Only available in Sea 3", false)
            end
        end

        local function scanElite()
            if not World3 then setv("elite", "Only available in Sea 3", false) return end
            local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
            if not commF then setv("elite", "Unable to read data", false) return end
            local ok, r = pcall(function() return commF:InvokeServer("EliteHunter", "Progress") end)
            setv("elite", ok and ("Hunted: " .. tostring(r)) or "Unable to read data", ok)
        end

        _G.MHSpawn(function()
            local n = 0
            while task.wait(1) do
                if statusPage.Visible then          -- chỉ quét khi đang mở tab Status (đỡ lag)
                    pcall(scanLight)
                    if n % 3 == 0 then pcall(scanHeavy) end
                    if n % 15 == 0 then _G.MHSpawn(function() pcall(scanElite) end) end
                    n += 1
                else
                    n = 0
                end
            end
        end)

        -- Status là tab đầu tiên và mở sẵn
        local data = tabs["Status"]
        data.Button.LayoutOrder = -1
        for _, d in pairs(tabs) do
            d.Page.Visible = false
            d.Indicator.Visible = false
            d.Button.TextColor3 = Color3.fromRGB(165, 168, 180)
            d.Button.BackgroundTransparency = 1
        end
        data.Page.Visible = true
        data.Indicator.Visible = true
        data.Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        data.Button.BackgroundTransparency = 0.9
        pageTitle.Text = "Status"

        -- Thứ tự tab giống Maru: Status, Farm Settings, Main, Multi Farm, Raid, Items, Shop, ESP
        for i, nm in ipairs({"Status", "Config", "Farm", "Boss", "Raid", "Gacha", "Shop", "ESP"}) do
            if tabs[nm] then tabs[nm].Button.LayoutOrder = i end
        end

        -- Tiêu đề nhóm trong từng trang cho dễ nhìn
        function MH.section(page, text, order)
            if not page then return end
            local lbl = Instance.new("TextLabel")
            lbl.Name = "Section_" .. text
            lbl.Size = UDim2.new(1, 0, 0, 22)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.TextSize = 13
            lbl.Font = Enum.Font.GothamBold
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.LayoutOrder = order
            lbl.Parent = page
        end
        MH.section(farmPage, "Farm", 10)
        MH.section(farmPage, "Material", 20)
        MH.section(farmPage, "Other Farm", 30)
        MH.section(bossPage, "Boss", -1)
        MH.section(bossPage, "Elite", 4)
        MH.section(raidPage, "Raid", -1)
        MH.section(gachaPage, "Bones", 0)
        MH.section(gachaPage, "Fruit", 2)
        MH.section(shopPage, "Shop", 0)
        MH.section(settingsPage, "Weapon & Distance", 0)
        MH.section(settingsPage, "Fast Attack & Bring Mob", 10)
        MH.section(settingsPage, "Haki & Race", 20)
        MH.section(settingsPage, "Misc", 30)
        MH.section(settingsPage, "Multi Stats", 40)
        -- MULTI-SELECT STATS: cho phép chọn nhiều nhóm chỉ số cùng lúc
        do
            local selectedStats = {Melee = true, Defense = false, Sword = false, Gun = false, ["Blox Fruit"] = false}
            local statNames = {"Melee", "Defense", "Sword", "Gun", "Blox Fruit"}
            local amount = 1
            local autoEnabled = false
            local running = false
            local order = 41
            local accent = BANANA_YELLOW or Color3.fromRGB(255, 190, 40)
            local panel = Instance.new("Frame")
            panel.Name = "MultiStatsPanel"
            panel.Size = UDim2.new(1, -4, 0, 172)
            panel.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
            panel.BackgroundTransparency = 0.08
            panel.BorderSizePixel = 0
            panel.LayoutOrder = order
            panel.Parent = settingsPage
            addCorner(panel, 8)
            addStroke(panel, Color3.fromRGB(65, 68, 80), 1)

            local heading = Instance.new("TextLabel")
            heading.Size = UDim2.new(1, -16, 0, 22)
            heading.Position = UDim2.new(0, 8, 0, 5)
            heading.BackgroundTransparency = 1
            heading.Text = "Select multiple stats (click to toggle)"
            heading.TextColor3 = Color3.fromRGB(240, 240, 245)
            heading.TextSize = 11
            heading.Font = Enum.Font.GothamBold
            heading.TextXAlignment = Enum.TextXAlignment.Left
            heading.Parent = panel

            local buttons = {}
            for i, statName in ipairs(statNames) do
                local b = Instance.new("TextButton")
                b.Name = "Stat_" .. statName:gsub("%s", "")
                b.Size = UDim2.new(0.19, -3, 0, 28)
                b.Position = UDim2.new((i - 1) * 0.2, 8, 0, 32)
                b.BackgroundColor3 = Color3.fromRGB(38, 40, 49)
                b.BorderSizePixel = 0
                b.AutoButtonColor = true
                b.TextSize = 10
                b.Font = Enum.Font.GothamBold
                b.TextColor3 = Color3.fromRGB(205, 208, 218)
                b.Parent = panel
                addCorner(b, 5)
                buttons[statName] = b
                local function refreshButton()
                    b.Text = (selectedStats[statName] and "✓ " or "□ ") .. statName
                    b.BackgroundColor3 = selectedStats[statName] and Color3.fromRGB(55, 95, 55) or Color3.fromRGB(38, 40, 49)
                    b.TextColor3 = selectedStats[statName] and Color3.fromRGB(220, 255, 220) or Color3.fromRGB(205, 208, 218)
                end
                refreshButton()
                b.MouseButton1Click:Connect(function()
                    selectedStats[statName] = not selectedStats[statName]
                    refreshButton()
                end)
            end

            local amountLabel = Instance.new("TextLabel")
            amountLabel.Size = UDim2.new(0, 105, 0, 26)
            amountLabel.Position = UDim2.new(0, 8, 0, 68)
            amountLabel.BackgroundTransparency = 1
            amountLabel.Text = "Points per allocation:"
            amountLabel.TextColor3 = Color3.fromRGB(220, 220, 228)
            amountLabel.TextSize = 10
            amountLabel.Font = Enum.Font.GothamMedium
            amountLabel.TextXAlignment = Enum.TextXAlignment.Left
            amountLabel.Parent = panel

            local amountBox = Instance.new("TextBox")
            amountBox.Name = "StatsAmount"
            amountBox.Size = UDim2.new(0, 90, 0, 26)
            amountBox.Position = UDim2.new(0, 112, 0, 68)
            amountBox.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
            amountBox.BorderSizePixel = 0
            amountBox.Text = "1"
            amountBox.PlaceholderText = "Enter point amount"
            amountBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            amountBox.TextSize = 12
            amountBox.Font = Enum.Font.GothamBold
            amountBox.ClearTextOnFocus = false
            amountBox.Parent = panel
            addCorner(amountBox, 5)
            addStroke(amountBox, Color3.fromRGB(65, 68, 80), 1)
            amountBox.FocusLost:Connect(function()
                local n = tonumber(amountBox.Text)
                amount = math.clamp(math.floor(n or 1), 1, 10000)
                amountBox.Text = tostring(amount)
            end)

            local function selectedCount()
                local n = 0
                for _, statName in ipairs(statNames) do if selectedStats[statName] then n += 1 end end
                return n
            end
            local status = Instance.new("TextLabel")
            status.Size = UDim2.new(1, -16, 0, 18)
            status.Position = UDim2.new(0, 8, 0, 98)
            status.BackgroundTransparency = 1
            status.Text = "Status: Ready"
            status.TextColor3 = Color3.fromRGB(150, 220, 150)
            status.TextSize = 10
            status.Font = Enum.Font.Gotham
            status.TextXAlignment = Enum.TextXAlignment.Left
            status.Parent = panel

            local function addSelectedPoints()
                if selectedCount() == 0 then status.Text = "Status: Select at least one stat" return end
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local commF = remotes and remotes:FindFirstChild("CommF_")
                if not commF then status.Text = "Status: CommF_ not found" return end
                local done = 0
                for _, statName in ipairs(statNames) do
                    if selectedStats[statName] then
                        local remoteStat = statName == "Blox Fruit" and "Demon Fruit" or statName
                        local ok = pcall(function() commF:InvokeServer("AddPoint", remoteStat, amount) end)
                        if ok then done += 1 end
                        task.wait(0.12)
                    end
                end
                status.Text = "Submitted stat allocation for " .. tostring(done) .. "/" .. tostring(selectedCount()) .. " stats (" .. tostring(amount) .. " points per stat)."
            end

            local addBtn = Instance.new("TextButton")
            addBtn.Name = "AddSelectedStats"
            addBtn.Size = UDim2.new(0.56, -10, 0, 27)
            addBtn.Position = UDim2.new(0, 8, 0, 125)
            addBtn.BackgroundColor3 = Color3.fromRGB(45, 110, 65)
            addBtn.BorderSizePixel = 0
            addBtn.Text = "ADD SELECTED STATS"
            addBtn.TextColor3 = Color3.new(1, 1, 1)
            addBtn.TextSize = 10
            addBtn.Font = Enum.Font.GothamBold
            addBtn.Parent = panel
            addCorner(addBtn, 5)
            addBtn.MouseButton1Click:Connect(addSelectedPoints)

            local autoBtn = Instance.new("TextButton")
            autoBtn.Name = "AutoMultiStats"
            autoBtn.Size = UDim2.new(0.44, -8, 0, 27)
            autoBtn.Position = UDim2.new(0.56, 4, 0, 125)
            autoBtn.BackgroundColor3 = Color3.fromRGB(48, 50, 60)
            autoBtn.BorderSizePixel = 0
            autoBtn.Text = "Auto Stats: OFF"
            autoBtn.TextColor3 = Color3.fromRGB(235, 235, 240)
            autoBtn.TextSize = 10
            autoBtn.Font = Enum.Font.GothamBold
            autoBtn.Parent = panel
            addCorner(autoBtn, 5)
            autoBtn.MouseButton1Click:Connect(function()
                autoEnabled = not autoEnabled
                autoBtn.Text = autoEnabled and "Auto Stats: ON" or "Auto Stats: OFF"
                autoBtn.BackgroundColor3 = autoEnabled and Color3.fromRGB(45, 110, 65) or Color3.fromRGB(48, 50, 60)
                if autoEnabled and not running then
                    running = true
                    _G.MHSpawn(function()
                        while autoEnabled do
                            pcall(addSelectedPoints)
                            task.wait(1)
                        end
                        running = false
                    end)
                end
            end)
        end

        MH.section(settingsPage, "Redeem Code", 50)
        MH.section(tabs["ESP"] and tabs["ESP"].Page, "ESP", 0)
    end)
    if not okSt then warn("[Status] Lỗi tạo tab Status:", errSt) end
end

-- Đã gỡ toàn bộ TAB Server Hop theo yêu cầu.

_G.MinhHubLoad(99, "Loading Shop...")
-- =========================================================
-- SHOP: MUA FIGHTING STYLE (MELEE) + BAY TỚI NPC
-- Tích hợp vào menu Shop hiện tại; chỉ chạy một kiểu võ tại một thời điểm.
-- Dùng _G.FlyStraight sẵn có để không tạo thêm hệ thống điều khiển bay chồng nhau.
-- =========================================================
_G.MHSpawn(function()
    local okInit, initErr = pcall(function()
    local STYLE_NPCS = {
        {id = "BuyBlackLegToggle", title = "Mua Black Leg", style = "BlackLeg", remote = "BuyBlackLeg", pos = {
            [1] = Vector3.new(-993.29, 27.30, 4024.69),
            [2] = Vector3.new(-4750.61, 35.08, -4846.33),
            [3] = Vector3.new(-5043.64, 371.35, -3183.40),
        }},
        {id = "BuyElectroToggle", title = "Mua Electro", style = "Electro", remote = "BuyElectro", pos = {
            [1] = Vector3.new(-4635.59, 13.46, -354.97),
            [2] = Vector3.new(-4863.81, 35.08, -4767.54),
            [3] = Vector3.new(-4993.20, 314.56, -3198.06),
        }},
        {id = "BuyFishmanKarateToggle", title = "Mua Fishman Karate", style = "FishmanKarate", remote = "BuyFishmanKarate", pos = {
            [1] = Vector3.new(61714.93, 52.18, 874.00),
            [2] = Vector3.new(-4960.04, 35.08, -4662.67),
            [3] = Vector3.new(-5017.39, 371.35, -3187.53),
        }},
        {id = "BuySuperhumanToggle", title = "Mua Superhuman", style = "Superhuman", remote = "BuySuperhuman", pos = {
            [2] = Vector3.new(1378.05, 247.43, -5189.37),
            [3] = Vector3.new(-4997.53, 371.35, -3197.46),
        }},
        {id = "BuyDeathStepToggle", title = "Mua Death Step", style = "DeathStep", remote = "BuyDeathStep", pos = {
            [2] = Vector3.new(6360.04, 296.67, -6763.93),
            [3] = Vector3.new(-4997.64, 314.56, -3220.37),
        }},
        {id = "BuySharkmanKarateToggle", title = "Mua Sharkman Karate", style = "SharkmanKarate", remote = "BuySharkmanKarate", pos = {
            [2] = Vector3.new(-2602.40, 239.22, -10314.75),
            [3] = Vector3.new(-4970.48, 314.56, -3225.04),
        }},
        {id = "BuyElectricClawToggle", title = "Mua Electric Claw", style = "ElectricClaw", remote = "BuyElectricClaw", pos = {
            [3] = Vector3.new(-10369.83, 331.69, -10126.49),
        }},
        {id = "BuyDragonTalonToggle", title = "Mua Dragon Talon", style = "DragonTalon", remote = "BuyDragonTalon", pos = {
            [3] = Vector3.new(5662.03, 1211.32, 858.60),
        }},
        {id = "BuyGodHumanToggle", title = "Mua Godhuman", style = "GodHuman", remote = "BuyGodhuman", pos = {
            [3] = Vector3.new(-13775.56, 334.66, -9877.67),
        }},
        {id = "BuySanguineArtToggle", title = "Mua Sanguine Art", style = "SanguineArt", remote = "BuySanguineArt", pos = {
            [3] = Vector3.new(-16514.86, 23.18, -190.84),
        }},
    }

    Q.MeleeShop = {running = false, token = 0, activeStyle = nil, status = "Sẵn sàng"}

    local statusCard = Instance.new("Frame")
    statusCard.Name = "MeleeShopStatus"
    statusCard.Size = UDim2.new(1, 0, 0, 50)
    statusCard.BackgroundColor3 = BANANA_CARD
    statusCard.LayoutOrder = 2
    statusCard.Parent = shopPage
    addCorner(statusCard, 8)
    addStroke(statusCard, BANANA_CARD_BORDER, 1.2)

    local statusTitle = Instance.new("TextLabel")
    statusTitle.Size = UDim2.new(1, -20, 0, 19)
    statusTitle.Position = UDim2.new(0, 10, 0, 3)
    statusTitle.BackgroundTransparency = 1
    statusTitle.Text = "🥋 MELEE FIGHTING STYLE SHOP"
    statusTitle.TextColor3 = BANANA_YELLOW
    statusTitle.TextSize = 11
    statusTitle.Font = Enum.Font.GothamBold
    statusTitle.TextXAlignment = Enum.TextXAlignment.Left
    statusTitle.Parent = statusCard

    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -20, 0, 23)
    statusText.Position = UDim2.new(0, 10, 0, 23)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Status: Ready"
    statusText.TextColor3 = Color3.fromRGB(205, 205, 212)
    statusText.TextSize = 10
    statusText.Font = Enum.Font.Gotham
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextWrapped = true
    statusText.Parent = statusCard

    local function setStatus(message)
        Q.MeleeShop.status = tostring(message)
        if statusText and statusText.Parent then
            statusText.Text = "Status: " .. Q.MeleeShop.status
        end
    end

    local function currentSea()
        if placeId == 2753915549 or placeId == 85211729168715 then return 1 end
        if placeId == 4442272183 or placeId == 79091703265657 then return 2 end
        if placeId == 7449423635 or placeId == 100117331123089 then return 3 end
        if World1 then return 1 end
        if World2 then return 2 end
        if World3 then return 3 end
        return currentSeaIndex
    end

    local function getRoot()
        local character = LocalPlayer.Character
        return character and character:FindFirstChild("HumanoidRootPart")
    end

    local function setOtherStyleTogglesOff(exceptId)
        for _, entry in ipairs(STYLE_NPCS) do
            if entry.id ~= exceptId and toggleUpdateFuncs[entry.id] then
                pcall(toggleUpdateFuncs[entry.id], false)
            end
        end
    end

    local function pauseTravelModes()
        -- Không bắt đầu giữa lúc một hệ thống khác đang ở giữa thao tác di chuyển.
        if _G.FruitPickupBusy or _G.PirateRaidBusy or _G.EliteBusy then
            return nil, "Fruit collection/Raid/Boss activity is in progress. Wait for it to finish and try again."
        end
        if Q.DK and Q.DK.on then
            return nil, "Disable Auto Dough King before traveling to purchase a fighting style."
        end

        local saved = {
            farm = autoFarmEnabled,
            material = autoFarmMaterialEnabled,
            raid = autoRaidEnabled,
            chest = autoChestEnabled,
            dungeon = _G.Dungeon,
            pickup = _G.AutoPickupFruit,
            pirateRaid = _G.PirateRaidFarm,
            elite = _G.EliteHunter,
            tyrantFarm = _G.TyrantFarm,
            tyrantSummon = _G.TyrantSummon,
            randomFruit = autoRandomFruitEnabled,
        }

        autoFarmEnabled = false
        autoFarmMaterialEnabled = false
        autoRaidEnabled = false
        autoChestEnabled = false
        _G.Dungeon = false
        _G.AutoPickupFruit = false
        _G.PirateRaidFarm = false
        _G.EliteHunter = false
        _G.TyrantFarm = false
        _G.TyrantSummon = false
        autoRandomFruitEnabled = false

        for _, id in ipairs({"AutoFarmTargetToggle", "AutoFarmMaterialToggle", "AutoRaidToggle", "AutoFarmChestToggle", "AutoPickupFruitToggle", "AutoRandomFruitToggle", "AutoEliteHunterToggle", "AutoTyrantFarmToggle", "AutoTyrantSummonToggle"}) do
            if toggleUpdateFuncs[id] then pcall(toggleUpdateFuncs[id], false) end
        end
        stopAllFlying()
        return saved
    end

    local function resumeTravelModes(saved)
        if not saved then return end
        autoFarmEnabled = saved.farm
        autoFarmMaterialEnabled = saved.material
        autoRaidEnabled = saved.raid
        autoChestEnabled = saved.chest
        _G.Dungeon = saved.dungeon
        _G.AutoPickupFruit = saved.pickup
        _G.PirateRaidFarm = saved.pirateRaid
        _G.EliteHunter = saved.elite
        _G.TyrantFarm = saved.tyrantFarm
        _G.TyrantSummon = saved.tyrantSummon
        autoRandomFruitEnabled = saved.randomFruit

        local toggles = {
            {"AutoFarmTargetToggle", saved.farm},
            {"AutoFarmMaterialToggle", saved.material},
            {"AutoRaidToggle", saved.raid},
            {"AutoFarmChestToggle", saved.chest},
            {"AutoPickupFruitToggle", saved.pickup},
            {"AutoRandomFruitToggle", saved.randomFruit},
            {"AutoEliteHunterToggle", saved.elite},
            {"AutoTyrantFarmToggle", saved.tyrantFarm},
            {"AutoTyrantSummonToggle", saved.tyrantSummon},
        }
        for _, row in ipairs(toggles) do
            if toggleUpdateFuncs[row[1]] then pcall(toggleUpdateFuncs[row[1]], row[2] == true) end
        end
    end

    local function runPurchase(entry, token, sea, npcPos, saved)
        local successMessage = nil
        local failureMessage = nil
        -- Tất cả luồng mua võ đều BAY THẬT bằng TweenService ở tốc độ 190.
        -- Không dùng CFrame để nhảy thẳng tới NPC hoặc cổng.
        _G.MeleeInstantTravel = false

        local ok, err = pcall(function()
            -- Fishman Karate ở Sea 1 nằm trong Underwater City.
            -- Không bay thẳng tới tọa độ X > 50000 từ ngoài biển: phải qua whirlpool/requestEntrance trước.
            if entry.style == "FishmanKarate" and sea == 1 then
                local transitDeadline = os.clock() + 75
                Q.gateArriveAt = nil
                Q.flyingToGate = false
                setStatus("Sea 1 — đang bay tới cổng xoáy Underwater City (tốc độ 190)...")

                while os.clock() < transitDeadline do
                    if not (Q.MeleeShop.running and Q.MeleeShop.token == token and _G.BuyMeleeActive == true) then
                        failureMessage = "Fishman Karate purchase canceled."
                        return
                    end

                    local root = getRoot()
                    if root and root.Position.X >= 50000 then
                        -- Đã chuyển đến vùng Underwater City; tiếp tục bay tới NPC dạy võ.
                        break
                    end

                    if root then
                        local enterOk, enterResult = pcall(function()
                            return Q.enterIfNeeded(root, npcPos, "melee-shop")
                        end)
                        if not enterOk then
                            error("Lỗi khi đi qua cổng vào Underwater City: " .. tostring(enterResult))
                        end
                    end
                    task.wait(0.25)
                end

                local root = getRoot()
                if not root or root.Position.X < 50000 then
                    error("Chưa vào được Underwater City sau 75 giây. Hãy kiểm tra cổng xoáy Sea 1 và thử lại.")
                end
                setStatus("Đã vào Underwater City — đang bay tới NPC Fishman Karate (tốc độ 190)...")
            end

            -- Sea 2: nếu đang ở trong Thuyền Ma nhưng NPC mua võ nằm ngoài,
            -- phải thoát qua cửa bên trong (922.90, 128.40, 32841.96) trước khi bay tới NPC.
            -- Vòng lặp chờ bộ điều phối xác nhận đã sang đúng phía, tránh tween thẳng qua khoảng cách lớn.
            if World2 then
                local transitDeadline = os.clock() + 75
                local function inCursedShip(pos)
                    return Q.isCursedShipPosition(pos)
                end
                while os.clock() < transitDeadline do
                    if not (Q.MeleeShop.running and Q.MeleeShop.token == token and _G.BuyMeleeActive == true) then
                        failureMessage = "Fighting-style purchase canceled."
                        return
                    end

                    local root = getRoot()
                    if not root then
                        task.wait(0.25)
                    else
                        local playerInShip = inCursedShip(root.Position)
                        local npcInShip = inCursedShip(npcPos)
                        if playerInShip == npcInShip then break end

                        local transitOk, transitErr = pcall(function()
                            return Q.enterIfNeeded(root, npcPos, "melee-shop")
                        end)
                        if not transitOk then
                            error("Lỗi khi thoát Thuyền Ma trước khi mua võ: " .. tostring(transitErr))
                        end
                        task.wait(0.25)
                    end
                end

                local root = getRoot()
                if not root or inCursedShip(root.Position) ~= inCursedShip(npcPos) then
                    error("Chưa thoát/đi qua cổng Thuyền Ma thành công trong 75 giây; chưa thể bay tới NPC mua võ.")
                end
            end

            setStatus("Sea " .. sea .. " — đang bay tới NPC " .. entry.style .. " (tốc độ 190)...")
            local destination = npcPos + Vector3.new(0, 3, 0)
            local arrived = false
            if Q.MeleeShop.running and Q.MeleeShop.token == token and _G.BuyMeleeActive == true then
                local root = getRoot()
                if root then
                    local distance = (root.Position - destination).Magnitude
                    if distance <= 3 then
                        arrived = true
                    else
                        -- Bay vật lý bằng TweenService: không gán CFrame để dịch chuyển.
                        -- Thời lượng = khoảng cách / 190 studs mỗi giây.
                        if currentFlyTween then
                            pcall(function() currentFlyTween:Cancel() end)
                            currentFlyTween = nil
                        end
                        if currentRaidTween then
                            pcall(function() currentRaidTween:Cancel() end)
                            currentRaidTween = nil
                        end

                        local duration = math.max(distance / 190, 0.05)
                        local tween = TweenService:Create(
                            root,
                            TweenInfo.new(duration, Enum.EasingStyle.Linear),
                            {CFrame = CFrame.new(destination)}
                        )
                        currentRaidTween = tween
                        tween:Play()
                        local deadline = os.clock() + duration + 3

                        while tween.PlaybackState == Enum.PlaybackState.Playing and os.clock() < deadline do
                            if not (Q.MeleeShop.running and Q.MeleeShop.token == token and _G.BuyMeleeActive == true) then
                                pcall(function() tween:Cancel() end)
                                if currentRaidTween == tween then currentRaidTween = nil end
                                failureMessage = "Đã hủy thao tác bay tới NPC."
                                return
                            end
                            task.wait()
                        end

                        if currentRaidTween == tween then currentRaidTween = nil end
                        if tween.PlaybackState == Enum.PlaybackState.Playing then
                            pcall(function() tween:Cancel() end)
                        end
                        task.wait(0.1)
                        root = getRoot()
                        arrived = root ~= nil and (root.Position - destination).Magnitude <= 12
                    end
                end
            end

            if not (Q.MeleeShop.running and Q.MeleeShop.token == token and _G.BuyMeleeActive == true) then
                failureMessage = "Fighting-style purchase canceled."
                return
            end
            if not arrived then
                error("Không tới được NPC trong thời gian cho phép; thử lại khi nhân vật đã hồi sinh/đứng ổn định.")
            end

            local hrp = getRoot()
            if not hrp or (hrp.Position - npcPos).Magnitude > 12 then
                error("Not close enough to the NPC to send the purchase request.")
            end

            local commF = getCommF()
            if not commF then error("ReplicatedStorage.Remotes.CommF_ not found.") end

            setStatus("Reached the NPC — sending purchase request for " .. entry.style .. "...")
            local finished, callOk, callResult = false, false, nil
            _G.MHSpawn(function()
                callOk, callResult = pcall(function()
                    return commF:InvokeServer(entry.remote)
                end)
                finished = true
            end)

            local deadline = os.clock() + 8
            while not finished and os.clock() < deadline do
                if not (Q.MeleeShop.running and Q.MeleeShop.token == token and _G.BuyMeleeActive == true) then
                    failureMessage = "Fighting-style purchase canceled."
                    return
                end
                task.wait(0.1)
            end

            if not finished then
                error("The server did not respond to the purchase request after 8 seconds. Check Beli/Fragments and fighting-style unlock requirements.")
            end
            if not callOk then error("Purchase request failed: " .. tostring(callResult)) end

            successMessage = "Đã bay tới NPC và gửi lệnh " .. entry.remote .. "; check the Fighting Styles list in-game."
            if callResult ~= nil then
                successMessage = successMessage .. " Response: " .. tostring(callResult):sub(1, 70)
            end
        end)

        if not ok then failureMessage = tostring(err) end

        -- Chỉ tác vụ hiện hành được dọn trạng thái, tránh đè lên một tác vụ mới.
        if Q.MeleeShop.token == token then
            _G.BuyMeleeActive = false
            _G.MeleeInstantTravel = false
            Q.gateArriveAt = nil
            Q.MeleeShop.running = false
            Q.MeleeShop.activeStyle = nil
            stopAllFlying()
            resumeTravelModes(saved)
            for _, item in ipairs(STYLE_NPCS) do
                if toggleUpdateFuncs[item.id] then pcall(toggleUpdateFuncs[item.id], false) end
            end
            if successMessage then
                setStatus(successMessage)
            elseif failureMessage then
                setStatus(failureMessage)
            else
                setStatus("Finished.")
            end
        else
            -- Nếu token đổi do người dùng bấm tắt, job cũ vẫn phải khôi phục Auto Farm.
            _G.BuyMeleeActive = false
            _G.MeleeInstantTravel = false
            Q.gateArriveAt = nil
            Q.MeleeShop.running = false
            Q.MeleeShop.activeStyle = nil
            stopAllFlying()
            resumeTravelModes(saved)
            for _, item in ipairs(STYLE_NPCS) do
                if toggleUpdateFuncs[item.id] then pcall(toggleUpdateFuncs[item.id], false) end
            end
            setStatus(failureMessage or "Fighting-style purchase canceled.")
        end
    end

    for index, entry in ipairs(STYLE_NPCS) do
        createToggleFeature(shopPage, entry.id, entry.title,
            "Travel to the NPC in the current Sea and send the purchase request for " .. entry.style .. ". Enough money and unlock requirements are needed.",
            index + 2, false, function(enabled)
                if not enabled then
                    if Q.MeleeShop.running and Q.MeleeShop.activeStyle == entry.style then
                        Q.MeleeShop.token = Q.MeleeShop.token + 1
                        _G.BuyMeleeActive = false
                        setStatus("Canceling " .. entry.style .. "...")
                    end
                    return
                end

                if Q.MeleeShop.running then
                    if toggleUpdateFuncs[entry.id] then pcall(toggleUpdateFuncs[entry.id], false) end
                    setStatus("Running " .. tostring(Q.MeleeShop.activeStyle) .. "; turn off the active toggle to cancel it first.")
                    return
                end

                local sea = currentSea()
                local npcPos = entry.pos[sea]
                if not npcPos then
                    if toggleUpdateFuncs[entry.id] then pcall(toggleUpdateFuncs[entry.id], false) end
                    setStatus(entry.style .. " không có NPC được cấu hình ở Sea " .. tostring(sea) .. ".")
                    return
                end

                local saved, pauseError = pauseTravelModes()
                if not saved then
                    if toggleUpdateFuncs[entry.id] then pcall(toggleUpdateFuncs[entry.id], false) end
                    setStatus(pauseError or "Unable to start moving right now.")
                    return
                end

                Q.MeleeShop.token = Q.MeleeShop.token + 1
                local token = Q.MeleeShop.token
                Q.MeleeShop.running = true
                Q.MeleeShop.activeStyle = entry.style
                _G.BuyMeleeActive = true
                setOtherStyleTogglesOff(entry.id)
                setStatus("Enabled " .. entry.style .. " — preparing to fly to the NPC...")
                _G.MHSpawn(function()
                    runPurchase(entry, token, sea, npcPos, saved)
                end)
            end)
    end

    _G.CancelMeleePurchase = function()
        if not Q.MeleeShop.running then
            setStatus("No fighting-style purchase is currently running.")
            return
        end
        Q.MeleeShop.token = Q.MeleeShop.token + 1
        _G.BuyMeleeActive = false
        setStatus("Canceling fighting-style purchase...")
    end
    end)
    if not okInit then
        warn("[MeleeShop] Không khởi tạo được giao diện mua võ:", initErr)
    end
end)





-- MENU SAFETY: đảm bảo ScreenGui không bị tắt/ẩn sau khi thêm module Shop.
task.defer(function()
    pcall(function()
        if screenGui then
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not screenGui.Parent and pg then
                screenGui.Parent = pg
            end
            screenGui.Enabled = true  -- bảo đảm menu được hiển thị sau khi toàn bộ script đã chạy đến cuối
        end
        if mainFrame then mainFrame.Visible = true end
        if toggleBtn then toggleBtn.Visible = true end
    end)
end)

-- LOADING: báo đã tải xong toàn bộ script
_G.MinhHubLoadDone()
