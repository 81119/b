anti-afk
table.insert(Hub.Conns, LP.Idled:Connect(function()
	pcall(function() game:GetService("VirtualUser"):ClickButton2(Vector2.new()) end)
end))

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

UI =====
local UI = loadstring(game:HttpGet("https://ai.zeinstore.xyz/prism.luau"))()
Hub.UI = UI
UI:SetTitle("By.81119 | Egg Opener (No Animation)")

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

Auto loop 
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

task.spawn(function()
	while Hub.Running do
		if Hub.Flags.NoAnim and openEggs and not openEggs.Disabled then
			pcall(function() openEggs.Disabled = true end)
		end
		ensureBypass()
		task.wait(2)
	end
end)

