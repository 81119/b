if getgenv().TwoK then pcall(getgenv().TwoK.Stop) end
local Hub = {
	Running = true,
	Flags = { Delay = 1.8, Backoff = 4, Triple = false, Oct = false, NoAnim = true, Auto = false, EggId = nil },
	Stats = { Ok = 0, Fail = 0, Pets0 = 0 },
	Conns = {},
}
getgenv().TwoK = Hub

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local Lib = require(RS:WaitForChild("Framework"):WaitForChild("Library"))
while not Lib.Loaded do task.wait(0.1) end

-- ===== 1) BYPASS anti-tamper ของ Network (ubvalue 1 = _check) =====
local function ensureBypass()
	return (pcall(function()
		debug.setupvalue(Lib.Network.Invoke, 1, function() return true end) -- บังคับ _check -> true
	end))
end
ensureBypass()

-- ===== 2) ปิด LocalScript ที่เล่นอนิเมชันเปิดไข่ =====
local openEggs
pcall(function()
	openEggs = LP.PlayerScripts.Scripts.Game["Open Eggs"]
end)
local function setAnimDisabled(dis)
	if openEggs then pcall(function() openEggs.Disabled = dis end) end
end
local function petCount()
	local s = Lib.Save.Get()
	return s and #s.Pets or 0
end

-- ===== 3) สแกนไข่ในแมพ (เรียงตามระยะ) =====
local function scanEggs()
	local pos = Vector3.zero
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if hrp then pos = hrp.Position end
	local seen, list = {}, {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") then
			local id = d:GetAttribute("ID")
			local c = d:FindFirstChild("Center")
			if id and c and not seen[id] then
				seen[id] = true
				list[#list + 1] = { id = id, dist = math.floor((c.Position - pos).Magnitude) }
			end
		end
	end
	table.sort(list, function(a, b) return a.dist < b.dist end)
	return list
end

local eggMap, options = {}, {}
local function buildOptions()
	local list = scanEggs()
	options, eggMap = {}, {}
	for i = 1, math.min(#list, 60) do
		local e = list[i]
		local lbl = string.format("%s  •  %d", e.id, e.dist)
		options[#options + 1] = lbl
		eggMap[lbl] = e.id
	end
	if #options == 0 then
		for _, id in ipairs({ "Yarn Egg", "Paw Egg", "Cat Egg", "Golden Paw Egg" }) do
			options[#options + 1] = id .. "  •  ?"
			eggMap[options[#options]] = id
		end
	end
	return options
end

-- ===== 4) ตัวยิงรีโมทเปิดไข่ =====
local function openOnce()
	if not Hub.Flags.EggId then return false, "ยังไม่ได้เลือกไข่" end
	ensureBypass()
	local ok, res, err = pcall(function()
		return Lib.Network.Invoke("Buy Egg", Hub.Flags.EggId, Hub.Flags.Triple, Hub.Flags.Oct)
	end)
	if not ok then
		Hub.Stats.Fail += 1
		return false, "error: " .. tostring(res)
	end
	if res then
		Hub.Stats.Ok += 1
		Hub.LastErr = nil
		return true
	end
	Hub.Stats.Fail += 1
	Hub.LastErr = tostring(err)
	return false, tostring(err)
end

-- ===== 5) UI =====
local UI = loadstring(game:HttpGet("https://ai.zeinstore.xyz/prism.luau"))()
Hub.UI = UI
UI:SetTitle("2K | Egg Opener (No Animation)")

local Tab = UI:Tab("EGG OPENER")
local S1 = Tab:Section("ไข่ที่ต้องการ / EGG")
local S2 = Tab:Section("ไม่มีอนิเมชัน / NO CUTSCENE")
local S3 = Tab:Section("เปิดไข่เร็ว & พร้อมกัน / SPEED")
local S4 = Tab:Section("สถานะ / STATUS")

local opts = buildOptions()
Hub.Flags.EggId = eggMap[opts[1]]

S1:Dropdown({
	Name = "เลือกไข่ (ใกล้สุดก่อน)",
	Options = opts,
	Default = opts[1],
	Callback = function(v)
		Hub.Flags.EggId = eggMap[v]
	end,
})
S1:Button({
	Name = "รีเฟรชรายชื่อไข่",
	Callback = function()
		local o = buildOptions()
		Hub.Flags.EggId = eggMap[o[1]]
		UI:Notify({ Title = "รีเฟรชแล้ว", Text = string.format("เจอ %d ไข่ในแมพ", #o), Duration = 3 })
	end,
})

S2:Toggle({
	Name = "ปิดอนิเมชันเปิดไข่ (Instant)",
	Desc = "ปิดสคริปต์ Open Eggs ฝั่งไคลเอนต์ → ไม่มีซีน/กล้อง/ป๊อปอัพ แต่ยังได้เพ็ท",
	Default = true,
	Callback = function(v)
		Hub.Flags.NoAnim = v
		setAnimDisabled(v)
	end,
})

S3:Toggle({
	Name = "เปิดไข่ x3 (Triple)",
	Default = false,
	Callback = function(v) Hub.Flags.Triple = v end,
})
S3:Toggle({
	Name = "เปิดไข่ x8 (Octuple)",
	Default = false,
	Callback = function(v) Hub.Flags.Oct = v end,
})
S3:Slider({
	Name = "ระยะห่างการยิง (วินาที)",
	Min = 0.3, Max = 5, Step = 0.1, Default = 1.8,
	Callback = function(v) Hub.Flags.Delay = v end,
})
S3:Slider({
	Name = "พักเมื่อโดน 'too quickly' (วินาที)",
	Min = 1, Max = 15, Step = 0.5, Default = 4,
	Callback = function(v) Hub.Flags.Backoff = v end,
})
S3:Toggle({
	Name = "Auto Open (วนเปิดอัตโนมัติ)",
	Default = false,
	Callback = function(v)
		Hub.Flags.Auto = v
		Hub.Stats.Pets0 = petCount()
	end,
})
S3:Button({
	Name = "เปิดไข่ 1 ครั้ง (ทดสอบ)",
	Callback = function()
		local ok, err = openOnce()
		UI:Notify({
			Title = ok and "เปิดสำเร็จ" or "เปิดไม่สำเร็จ",
			Text = ok and ("+" .. tostring(petCount() - Hub.Stats.Pets0) .. " เพ็ท (สะสม)") or tostring(err),
			Duration = 3,
		})
	end,
})

S4:Label("Delay 1.5–2s = จังหวะที่เซิร์ฟเวอร์รับ (ต่ำกว่านี้จะโดน 'You are doing this too quickly!')")
S4:Label("ปิดอนิเมชัน + ยิงรีโมทเอง = ไม่มีซีนเลย แต่เพ็ทยังเข้าตัวจริง")

-- ===== 6) Auto loop =====
task.spawn(function()
	while Hub.Running do
		if Hub.Flags.Auto then
			local ok, err = openOnce()
			if ok then
				task.wait(Hub.Flags.Delay)
			else
				if err and string.find(string.lower(err), "quick") then
					task.wait(Hub.Flags.Backoff)
				else
					task.wait(Hub.Flags.Delay)
				end
			end
		else
			task.wait(0.15)
		end
	end
end)

-- ===== 7) watchdog: คงการปิดอนิเมชัน + bypass ไว้ตลอด =====
task.spawn(function()
	while Hub.Running do
		if Hub.Flags.NoAnim and openEggs and not openEggs.Disabled then
			pcall(function() openEggs.Disabled = true end)
		end
		ensureBypass()
		task.wait(2)
	end
end)

-- ===== 8) status bar =====
task.spawn(function()
	while Hub.Running do
		UI:SetStatus(string.format(
			"ไข่: %s | สำเร็จ %d | พลาด %d | เพ็ท +%d | Delay %.1fs",
			tostring(Hub.Flags.EggId), Hub.Stats.Ok, Hub.Stats.Fail,
			petCount() - Hub.Stats.Pets0, Hub.Flags.Delay
		))
		task.wait(0.5)
	end
end)

-- ===== 9) anti-afk =====
table.insert(Hub.Conns, LP.Idled:Connect(function()
	pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end)
end))

function Hub.Stop()
	Hub.Running = false
	if openEggs then pcall(function() openEggs.Disabled = false end) end -- คืนอนิเมชัน
	for _, c in ipairs(Hub.Conns) do pcall(function() c:Disconnect() end) end
	Hub.Conns = {}
	pcall(function() UI:Destroy() end)
end

UI:AddSettingsTab()
UI:Toggle(true)