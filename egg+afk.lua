local VirtualUser = game:GetService("VirtualUser")
local Player = game:GetService("Players").LocalPlayer

Player.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

for i,v in pairs(getgc(true)) do
   if (typeof(v) == 'table' and rawget(v, 'OpenEgg')) then
       v.OpenEgg = function()
           return
       end
   end
end