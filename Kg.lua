-- KG: часть 2. Авто-вратарь, ESP мяча, траектория, точка попадания мяча в ворота
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local LogService = game:GetService("LogService")

local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G
for _, k in ipairs({ "__KG_cleanup" }) do
	if env[k] then pcall(env[k]) end
end

local function copyText(s)
	local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	return fn and pcall(fn, s)
end

local host = (gethui and gethui()) or lp:WaitForChild("PlayerGui")
local o0 = host:FindFirstChild("KGUI")
if o0 then o0:Destroy() end
local sg = Instance.new("ScreenGui")
sg.Name, sg.ResetOnSpawn, sg.DisplayOrder = "KGUI", false, 998
sg.Parent = host

local boot = Instance.new("TextLabel")
boot.Size = UDim2.new(0, 260, 0, 22)
boot.AnchorPoint = Vector2.new(0.5, 0)
boot.Position = UDim2.new(0.5, 0, 0, 100)
boot.BackgroundColor3, boot.BackgroundTransparency = Color3.fromRGB(16, 16, 26), 0.3
boot.TextColor3, boot.Font, boot.TextSize = Color3.fromRGB(226, 229, 246), Enum.Font.GothamMedium, 12
boot.Text = "KG: запуск…"
boot.Parent = sg
Instance.new("UICorner", boot).CornerRadius = UDim.new(0, 8)

local function main()
	local playerGui = lp:WaitForChild("PlayerGui")
	local conns = {}
	local function C(sig, fn) conns[#conns + 1] = sig:Connect(fn) end
	local M = {}

	local CFG = {
		gk = true, gkExact = true, gkLearn = true, gkPre = true, gkPreDist = 32, gkPreSpeed = 70, gkPatience = false, gkYield = true, gkAir = true, gkRange = 120, gkMinSpeed = 14, gkReach = 10, gkReact = 0, gkSafe = 0.02, gkReachH = 6,
		homeOffset = 5, gkMaxOut = 20, gkOutK = 0.12, gkLeash = 46, gkBoxD = 58, gkBoxW = 0, gkOver = 1.5, gkZone = true, gkFace = true,
		gkInput = 1, gkManual = false, gkJumpHum = true, diveKey = "E", jumpKey = "Space", gkAlways = true, gkCombo = true, comboDelay = 0.1,
		gkAttack = true, gkLungeR = 11, gkTackle = true, gkClaim = true, gkClaimR = 38, gkClear = true,
		gkDiveLead = 0.6, gkPressDist = 70, gkKickOnly = true, gkKickDist = 7, gkKickJump = 12, gkPost = 0.4,
		gkThrow = true, gkThrowMin = 10, gkThrowMax = 90, thrSpeed = 85, arcMin = 45, thrExtra = 0.05,
		esp = true, traj = true, trajMin = 22, bounce = 0.6, gravity = workspace.Gravity, autoG = true, colorIdx = 1,
		hit = true, hitMin = 14,
	}

	-- ===== защита от ПК-режима: если тип ввода стал не-тач, возвращаем касанием =====
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		local busy = false
		C(UIS.LastInputTypeChanged, function(t)
			if busy or t == Enum.UserInputType.Touch then return end
			if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.MouseButton1
				or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseWheel then
				busy = true
				task.delay(0.1, function()
					local vy = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 600) / 2
					pcall(function() VIM:SendTouchEvent(11, 0, 4, vy) end)
					task.wait(0.05)
					pcall(function() VIM:SendTouchEvent(11, 2, 4, vy) end)
					task.wait(0.5)
					busy = false
				end)
			end
		end)
	end

	-- ===== лог =====
	local T0, LOG, ERRS = os.clock(), {}, {}
	local statusText = "Готово"
	local function ev(s)
		LOG[#LOG + 1] = string.format("[%6.1f] %s", os.clock() - T0, s)
		if #LOG > 120 then table.remove(LOG, 1) end
	end
	local function note(s) ev(s); statusText = s end
	C(LogService.MessageOut, function(msg, t)
		if t == Enum.MessageType.MessageError then
			ERRS[#ERRS + 1] = string.format("[%6.1f] %s", os.clock() - T0, tostring(msg):sub(1, 160))
			if #ERRS > 25 then table.remove(ERRS, 1) end
		end
	end)

	-- ===== утилиты =====
	local function norm(s) return (tostring(s):lower():gsub("%s+", "")) end
	local function flat(v) return Vector3.new(v.X, 0, v.Z) end
	local function rootOf(p) local c = p and p.Character; return c and c:FindFirstChild("HumanoidRootPart") end
	local function myRoot() return rootOf(lp) end
	local function myHum() local c = lp.Character; return c and c:FindFirstChildOfClass("Humanoid") end
	local function cam() return workspace.CurrentCamera end

	local function solveArc(d, h, v, g)
		local v2 = v * v
		local disc = v2 * v2 - g * (g * d * d + 2 * h * v2)
		local ang
		if disc < 0 then ang = math.rad(45) else ang = math.atan2(v2 - math.sqrt(disc), g * d) end
		return ang, d / (v * math.cos(ang))
	end
	local function teamRel(p)
		if p == lp then return "me" end
		if lp.Team ~= nil and p.Team ~= nil then return (lp.Team == p.Team) and "mate" or "enemy" end
		local function jc(q)
			local c = q.Character
			local j = c and c:FindFirstChild("TeamJersey")
			local col = j and j:GetAttribute("JerseyTeamColor")
			return typeof(col) == "Color3" and col or nil
		end
		local a, b = jc(lp), jc(p)
		if a and b then
			return (math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.05) and "mate" or "enemy"
		end
		return "unk"
	end

	local espF = Instance.new("Folder")
	espF.Name = "KG_ESP"
	espF.Parent = workspace
	local function newPart()
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material, p.Transparency = Enum.Material.Neon, 1
		p.Parent = espF
		return p
	end

	local home = { pos = nil, mouth = nil, fwd = Vector3.new(0, 0, -1), hw = 16, h = 12, top = nil, zone = nil, how = "—" }
	local S = { lastThreat = 0, lastDive = 0, lastClear = 0, lastLunge = 0, lastTackle = 0, tgt = nil, tgtT = 0, shot = nil,
		mode = "выкл", bspd = 0, eta = 0, hgt = 0, pressed = "", pressedT = -99 }
	M.thr = nil

	-- ===== кнопки игры =====
	local ACT = { kick = "kick", pass = "pass", lob = "lob", tackle = "tackle", jump = "jump", dive = "dive", request = "request",
		["удар"] = "kick", ["пас"] = "pass", ["навес"] = "lob", ["подкат"] = "tackle", ["прыжок"] = "jump", ["запрос"] = "request",
		["бросок"] = "dive", ["ныряние"] = "dive" }
	local function shown(g)
		local cur = g
		while cur and cur ~= playerGui do
			if cur:IsA("GuiObject") and not cur.Visible then return false end
			if cur:IsA("ScreenGui") and not cur.Enabled then return false end
			cur = cur.Parent
		end
		return g.AbsoluteSize.X > 0
	end
	local function buttons()
		local out = {}
		local mob = playerGui:FindFirstChild("Mobile")
		if mob then
			for _, g in ipairs(mob:GetDescendants()) do
				if g:IsA("GuiObject") and g.Name:match("^Button%d+$") and shown(g) then out[#out + 1] = g end
			end
		end
		return out
	end
	local function label(g)
		for _, d in ipairs(g:GetDescendants()) do
			if d:IsA("GuiObject") and ACT[norm(d.Name)] then return ACT[norm(d.Name)] end
		end
		for _, d in ipairs(g:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				local a = ACT[norm(d.Text)]
				if a then return a end
				local s = norm(d.Text)
				if s ~= "" and #s < 14 and not s:match("^[%d%.:%%x]+$") then return s end
			end
		end
		return norm(g.Name)
	end
	local function ctr(g)
		local s = g:FindFirstAncestorOfClass("ScreenGui")
		local inset = (s and s.IgnoreGuiInset) and Vector2.zero or GuiService:GetGuiInset()
		return g.AbsolutePosition + g.AbsoluteSize / 2 + inset
	end
	local function fake(c, state)
		return { UserInputType = Enum.UserInputType.Touch, UserInputState = state, KeyCode = Enum.KeyCode.Unknown,
			Position = Vector3.new(c.X, c.Y, 0), Delta = Vector3.zero }
	end
	local function gphase(c, state)
		if typeof(getconnections) ~= "function" then return end
		local sig = (state == Enum.UserInputState.Begin) and UIS.InputBegan or UIS.InputEnded
		local ok, list = pcall(getconnections, sig)
		if not ok or not list then return end
		for _, cn in ipairs(list) do
			if cn.Function then task.spawn(cn.Function, fake(c, state), false) end
		end
	end
	local GKIN = { { "auto", "авто (выученный)" }, { "touch", "касание" }, { "gui", "события кнопки" }, { "glob", "глобально" }, { "all", "все сразу" } }
	local CL = { pos = {}, fixed = {}, method = {}, learn = nil }
	local function candPos(g, kind)
		local list = { g.AbsolutePosition + g.AbsoluteSize / 2 }
		if kind and CL.pos[kind] then list[#list + 1] = CL.pos[kind] end
		list[#list + 1] = ctr(g)
		return list
	end
	local function fireSig(sig, ...)
		if typeof(getconnections) ~= "function" then return end
		local ok, list = pcall(getconnections, sig)
		if ok and list then
			for _, cn in ipairs(list) do
				if cn.Function then task.spawn(cn.Function, ...) end
			end
		end
	end
	-- VIM присылает касание со сдвигом (в твоей игре ≈ -49,-58), поэтому калибруем и компенсируем
	local function calibrate()
		local cam0 = workspace.CurrentCamera
		local vs = cam0 and cam0.ViewportSize or Vector2.new(800, 400)
		local sp = Vector2.new(vs.X * 0.5, vs.Y * 0.4)
		CL.cal = { sent = sp, got = nil }
		pcall(function() VIM:SendTouchEvent(19, 0, sp.X, sp.Y) end)
		task.wait(0.06)
		pcall(function() VIM:SendTouchEvent(19, 2, sp.X, sp.Y) end)
		task.wait(0.3)
		local got = CL.cal and CL.cal.got
		CL.cal = nil
		if got then
			CL.off = got - sp
			note(string.format("кликер: сдвиг касания (%.0f, %.0f) — учту", CL.off.X, CL.off.Y))
			ev(string.format("кликер: калибровка off=(%.1f, %.1f)", CL.off.X, CL.off.Y))
			return true
		end
		note("кликер: калибровка не удалась (касание не дошло)")
		return false
	end
	local tid = 20
	local function doTouch(c)
		local o = CL.off or Vector2.zero
		local sx, sy = c.X - o.X, c.Y - o.Y
		tid = (tid >= 29) and 20 or (tid + 1)
		local id = tid
		pcall(function() VIM:SendTouchEvent(id, 0, sx, sy) end)
		task.wait(0.08)
		pcall(function() VIM:SendTouchEvent(id, 2, sx, sy) end)
		task.wait(0.03)
		pcall(function() VIM:SendTouchEvent(id, 2, sx, sy) end)
	end
	local function doGui(g, c)
		local objs = { g }
		for _, d in ipairs(g:GetDescendants()) do
			if d:IsA("GuiObject") then objs[#objs + 1] = d end
		end
		for _, o in ipairs(objs) do
			fireSig(o.InputBegan, fake(c, Enum.UserInputState.Begin))
			if o:IsA("GuiButton") then fireSig(o.MouseButton1Down, c.X, c.Y) end
		end
		task.wait(0.07)
		for _, o in ipairs(objs) do
			fireSig(o.InputEnded, fake(c, Enum.UserInputState.End))
			if o:IsA("GuiButton") then
				fireSig(o.MouseButton1Up, c.X, c.Y)
				fireSig(o.MouseButton1Click)
				fireSig(o.Activated, fake(c, Enum.UserInputState.End), 1)
			end
		end
	end
	-- «отжать»: отпускаем все виртуальные касания и подвисшие события кнопок
	local function releaseAll()
		task.spawn(function()
			local o = CL.off or Vector2.zero
			for _, g in ipairs(buttons()) do
				local c = g.AbsolutePosition + g.AbsoluteSize / 2
				local sx, sy = c.X - o.X, c.Y - o.Y
				pcall(function() VIM:SendTouchEvent(11, 2, sx, sy) end)
				for id = 19, 29 do pcall(function() VIM:SendTouchEvent(id, 2, sx, sy) end) end
				local objs = { g }
				for _, d in ipairs(g:GetDescendants()) do
					if d:IsA("GuiObject") then objs[#objs + 1] = d end
				end
				for _, ob in ipairs(objs) do
					fireSig(ob.InputEnded, fake(c, Enum.UserInputState.End))
					if ob:IsA("GuiButton") then fireSig(ob.MouseButton1Up, c.X, c.Y) end
				end
				fireSig(UIS.InputEnded, fake(c, Enum.UserInputState.End), false)
			end
			note("кнопки отжаты")
		end)
	end
	local function runMethod(m, g, kind)
		local list = candPos(g, kind)
		if m == "touch" then doTouch(list[1])
		elseif m == "touch2" then doTouch(list[2])
		elseif m == "gui" then doGui(g, list[1])
		elseif m == "glob" then
			gphase(list[1], Enum.UserInputState.Begin)
			task.wait(0.07)
			gphase(list[1], Enum.UserInputState.End)
		end
	end
	local function press(g, how, kind)
		local m = how
		if m == "tg" then m = "all" end
		if m == "auto" then m = (kind and CL.method[kind]) or "touch" end
		task.spawn(function()
			if m == "all" then
				task.spawn(runMethod, "touch", g, kind)
				task.spawn(runMethod, "gui", g, kind)
				runMethod("glob", g, kind)
			else
				runMethod(m, g, kind)
			end
		end)
	end
	local function pressKey(name)
		do return false end -- клавиши отключены: игра переключалась на ПК-режим
		local ok, kc = pcall(function() return Enum.KeyCode[name] end)
		if not (ok and kc) then return false end
		task.spawn(function()
			pcall(function() VIM:SendKeyEvent(true, kc, false, game) end)
			task.wait(0.07)
			pcall(function() VIM:SendKeyEvent(false, kc, false, game) end)
		end)
		return true
	end
	local function tap(lab)
		local n = 0
		for _, g in ipairs(buttons()) do
			if label(g) == lab then press(g, "tg"); n += 1 end
		end
		return n > 0
	end

	-- ===== мячи =====
	local cands, BT = {}, {}
	local ball, bvel = nil, Vector3.zero
	do
		local BAD = { "goal", "net", "spawn", "pad", "zone", "keeper", "gate", "field", "ground", "wall", "trigger" }
		local function inChar(o)
			local cur = o.Parent
			while cur do
				if cur:IsA("Model") and cur:FindFirstChildOfClass("Humanoid") then return true end
				cur = cur.Parent
			end
			return false
		end
		local function consider(o)
			if not o:IsA("BasePart") or o:IsDescendantOf(espF) then return end
			local mx = math.max(o.Size.X, o.Size.Y, o.Size.Z)
			if mx < 0.8 or mx > 10 then return end
			local n = o.Name:lower()
			for _, b in ipairs(BAD) do if n:find(b, 1, true) then return end end
			if inChar(o) then return end
			local h = n:find("ball", 1, true) or n:find("soccer", 1, true) or n:find("football", 1, true)
			if not h then
				local p, d = o.Parent, 0
				while p and p ~= workspace and d < 3 do
					local pn = p.Name:lower()
					if pn:find("ball", 1, true) or pn:find("soccer", 1, true) then h = true break end
					p, d = p.Parent, d + 1
				end
			end
			if not h and o:IsA("Part") and o.Shape == Enum.PartType.Ball and mx >= 1.5 and mx <= 6 then h = true end
			if h then cands[o] = true end
		end
		task.spawn(function()
			local k = 0
			for _, o in ipairs(workspace:GetDescendants()) do
				consider(o)
				k += 1
				if k % 4000 == 0 then task.wait() end
			end
		end)
		C(workspace.DescendantAdded, consider)
	end
	local function count()
		local n = 0
		for o in pairs(cands) do
			if o.Parent then n += 1 else cands[o] = nil end
		end
		return n
	end
	local function track()
		local now = os.clock()
		for b in pairs(cands) do
			if not b.Parent then
				cands[b], BT[b] = nil, nil
			else
				local e = BT[b]
				if not e then e = { hist = {}, vel = Vector3.zero }; BT[b] = e end
				local h = e.hist
				h[#h + 1] = { now, b.Position }
				while #h > 2 and now - h[1][1] > 0.14 do table.remove(h, 1) end
				local mv = Vector3.zero
				if #h >= 2 then
					local span = h[#h][1] - h[1][1]
					if span > 0.03 then mv = (h[#h][2] - h[1][2]) / span end
				end
				if mv.Magnitude > 600 then mv = Vector3.zero end
				local av = b.AssemblyLinearVelocity
				local v = ((av - mv).Magnitude < 0.35 * math.max(mv.Magnitude, 10)) and av or mv
				if (v - e.vel).Magnitude > 20 then e.vel = v else e.vel = e.vel:Lerp(v, 0.5) end
			end
		end
	end
	local function nearest()
		local root = myRoot()
		if not root then return nil, math.huge end
		local best, bd = nil, math.huge
		for b in pairs(cands) do
			if b.Parent then
				local d = (b.Position - root.Position).Magnitude
				if d < bd then best, bd = b, d end
			else
				cands[b] = nil
			end
		end
		return best, bd
	end
	local function pickBall()
		local cur = ball
		if cur and cur.Parent and cands[cur] then
			local e = BT[cur]
			local moving = (e and e.vel.Magnitude > 4) or cur.AssemblyLinearVelocity.Magnitude > 4
			local r = myRoot()
			if moving and r and (cur.Position - r.Position).Magnitude < 150 then return end
		end
		local best, bs
		local r = myRoot()
		for b in pairs(cands) do
			if b.Parent then
				local s = -(b.Position - (r and r.Position or cam().CFrame.Position)).Magnitude
				local e = BT[b]
				if (e and e.vel.Magnitude > 3) or b.AssemblyLinearVelocity.Magnitude > 3 then s += 25 end
				if b.Transparency > 0.95 then s -= 40 end
				if not bs or s > bs then best, bs = b, s end
			end
		end
		ball = best
	end

	-- симуляция траектории (ворота исключены из лучей)
	local N, DT = 40, 0.06
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.RespectCanCollide = true
	local base, rpT = { espF }, 0
	local function sim(b, vel)
		if os.clock() - rpT > 0.5 then
			rpT = os.clock()
			base = { espF }
			for _, p in ipairs(Players:GetPlayers()) do if p.Character then base[#base + 1] = p.Character end end
			local mp = workspace:FindFirstChild("Map")
			local dt0 = mp and mp:FindFirstChild("Data")
			if dt0 then base[#base + 1] = dt0 end
		end
		local f = table.clone(base)
		f[#f + 1] = b
		rp.FilterDescendantsInstances = f
		local pos = b.Position
		local g, e = CFG.gravity, CFG.bounce
		local rad = math.max(b.Size.X, b.Size.Y, b.Size.Z) / 2
		local pts, lands = {}, {}
		local w = (M.curve and M.curve(b)) or 0 -- закрутка: поворот горизонтальной скорости (рад/с)
		for i = 1, N do
			if w ~= 0 then
				local a = w * DT
				local ca, sa = math.cos(a), math.sin(a)
				vel = Vector3.new(vel.X * ca - vel.Z * sa, vel.Y, vel.X * sa + vel.Z * ca)
				w = w * 0.985
			end
			local nv = vel - Vector3.new(0, g * DT, 0)
			local np = pos + (vel + nv) * 0.5 * DT
			local delta = np - pos
			local h = delta.Magnitude > 0.001 and workspace:Raycast(pos, delta.Unit * (delta.Magnitude + rad), rp)
			if h then
				local n = h.Normal
				local vn = nv:Dot(n)
				if vn < 0 then nv = (nv - n * vn) * 0.92 - n * vn * e end
				np = h.Position + n * rad
				if n.Y > 0.5 and #lands < 3 then lands[#lands + 1] = { pos = h.Position, t = i * DT } end
			end
			pos, vel = np, nv
			pts[i] = { pos = np, t = i * DT }
		end
		return pts, lands
	end

	-- ===== ворота =====
	local function goalList()
		local out = {}
		local map = workspace:FindFirstChild("Map")
		local data = map and map:FindFirstChild("Data")
		if not data then return out end
		local mid = Vector3.zero
		local bd = map:FindFirstChild("Boundaries")
		local fld = bd and bd:FindFirstChild("Ground") and bd.Ground:FindFirstChild("Field")
		if fld and fld:IsA("BasePart") then mid = fld.Position end
		for _, t in ipairs(data:GetChildren()) do
			local g = t:FindFirstChild("Goal")
			if g and g:IsA("BasePart") then
				local z = t:FindFirstChild("Goalkeeper")
				local zn = {}
				for _, d in ipairs(t:GetDescendants()) do
					if d:IsA("BasePart") and d ~= g then
						local nm = d.Name:lower()
						if nm:find("zone", 1, true) or nm:find("area", 1, true) or nm:find("box", 1, true) or nm:find("penal", 1, true) or nm:find("keeper", 1, true) or nm:find("gk", 1, true) then
							zn[#zn + 1] = d.Name .. string.format("(%.0fx%.0f)", d.Size.X, d.Size.Z)
							if not (z and z:IsA("BasePart")) or d.Size.X * d.Size.Z > z.Size.X * z.Size.Z then z = d end
						end
					end
				end
				if #zn > 0 then
					local msg = "зоны " .. t.Name .. ": " .. table.concat(zn, ", ")
					if M.zlog ~= msg then M.zlog = msg; ev(msg) end
				end
				local cf, s = g.CFrame, g.Size
				local wLen, dAxis, dLen
				if s.X >= s.Z then wLen, dAxis, dLen = s.X, cf.LookVector, s.Z else wLen, dAxis, dLen = s.Z, cf.RightVector, s.X end
				dAxis = flat(dAxis).Unit
				if flat(mid - g.Position):Dot(dAxis) < 0 then dAxis = -dAxis end
				local m = g.Position + dAxis * (dLen / 2)
				out[#out + 1] = {
					name = t.Name, zone = (z and z:IsA("BasePart")) and z or nil,
					mouth = Vector3.new(m.X, g.Position.Y - s.Y / 2, m.Z), fwd = dAxis,
					right = Vector3.new(-dAxis.Z, 0, dAxis.X), hw = wLen / 2, h = s.Y, top = g.Position.Y + s.Y / 2,
				}
			end
		end
		return out
	end
	local function detect()
		local root = myRoot()
		if not root then return false end
		local best, bd
		for _, e in ipairs(goalList()) do
			local d = flat(e.mouth - root.Position).Magnitude
			if not bd or d < bd then best, bd = e, d end
		end
		if best then
			home.mouth = Vector3.new(best.mouth.X, root.Position.Y, best.mouth.Z)
			home.fwd = best.fwd
			home.pos = home.mouth + best.fwd * CFG.homeOffset
			home.hw, home.h, home.top, home.zone = best.hw, bes
