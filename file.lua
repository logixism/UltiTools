local Material = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kinlei/MaterialLua/master/Module.lua"))()
local DragControlIer = game:GetService("ReplicatedStorage").ClientBridge.DragControlIer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService('GuiService')
local Debris = game:GetService("Debris")

function GetItem(item)
    local item = Player.Backpack:FindFirstChild(item)
    if item then
        item.Parent = Player.Character
    end
end

function StoreItems()
    for i,v in pairs(Player.Character:GetChildren()) do
        if v:IsA("Tool") then
           v.Parent = Player.Backpack
        end
    end
end

function RemoveSelection()
    for i,v in pairs(getgenv().Selected) do
        local sbox = v:FindFirstChild("SelectionBox")
        if sbox then
            sbox:Destroy()
        end
    end
end

function copy(part, cFrame)
    GetItem("Clone")
    local success, key, part = DragControlIer:InvokeServer("GetKey", part, true)
    if success then
        DragControlIer.Update:FireServer("Update", key, cFrame)
        DragControlIer.Update:FireServer("ClearKey", key)
    end
    StoreItems()
    return success and part
end

function drag(part, cFrame)
    GetItem("Drag")
    local success, key, part = DragControlIer:InvokeServer("GetKey", part, false)
    if success then
        DragControlIer.Update:FireServer("Update", key, cFrame)
        DragControlIer.Update:FireServer("ClearKey", key)
    end
    StoreItems()
    return success and part
end

local function GetChildrenWhichAre(where, class)
    local rtable = {}
    for i,v in pairs(where:GetChildren()) do
        if v:IsA(class) then
            table.insert(rtable, v)
        end
    end
    
    return rtable
end

local ColorForSelection = Color3.fromRGB(0,0,0)

spawn(function()
	while wait() do
		local t = 60
		local hue = tick() % t / t

		ColorForSelection = Color3.fromHSV(hue, 1, 1)
	end
end)

getgenv().Selected = {}

spawn(function()
    while wait(0.1) do
        for i,v in pairs(getgenv().Selected) do
            local sel = Instance.new("SelectionBox")
            sel.Parent = v
            sel.Adornee = v
            sel.Color3 = ColorForSelection
            
            Debris:AddItem(sel, 0.101)
        end
    end
end)

local Inset = GuiService:GetGuiInset()
local Camera = workspace.CurrentCamera
local GUI = Instance.new("ScreenGui")
GUI.Parent = Player.PlayerGui

local selectionFrame = Instance.new("Frame", GUI)
selectionFrame.AnchorPoint = Vector2.new(0.5, 0.5)
selectionFrame.Transparency = 0.7

local mouseDown = false
getgenv().SelectEquipped = false
local lastPos

local function To3dSpace(pos)
	return Camera:ScreenPointToRay(pos.x, pos.y).Origin 
end


local function CalcSlope(vec)
	local rel = Camera.CFrame:pointToObjectSpace(vec)
	return Vector2.new(rel.x/-rel.z, rel.y/-rel.z)
end


local function Overlaps(cf, a1, a2)
	local rel = Camera.CFrame:ToObjectSpace(cf)
	local x, y = rel.x / -rel.z, rel.y / -rel.z

	return (a1.x) < x and x < (a2.x) 
		and (a1.y < y and y < a2.y) and rel.z < 0 
end


local function Swap(a1, a2)
	return Vector2.new(math.min(a1.x, a2.x), math.min(a1.y, a2.y)), 
		Vector2.new(math.max(a1.x, a2.x), math.max(a1.y, a2.y))
end


local function Search(objs, p1, p2)
	local Found = {}
	local a1 = CalcSlope(p1)
	local a2 = CalcSlope(p2)
	
	a1, a2 = Swap(a1, a2)
	
	for _ ,obj in ipairs(objs) do
		
		local cf = obj:IsA("Model")
			and obj:GetBoundingBox() or obj.CFrame
		
		if Overlaps(cf,a1, a2) then
			table.insert(Found, obj)
		end
	end

	return Found
end
	
UserInputService.InputBegan:Connect(function(input) 
	if input.UserInputType == Enum.UserInputType.MouseButton1 and getgenv().SelectEquipped then
		lastPos = Vector2.new(input.Position.x, input.Position.y) 
		mouseDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and getgenv().SelectEquipped then
		
		local pos = Vector2.new(input.Position.x, input.Position.y)
		local result = Search(GetChildrenWhichAre(workspace, "BasePart"), To3dSpace(lastPos), To3dSpace(pos))
		mouseDown = false; selectionFrame.Visible = false 
		
		getgenv().Selected = {}
		
		for i,v in pairs(result) do
			table.insert(getgenv().Selected, v)
		end
	end
end)


RunService.Heartbeat:Connect(function()
	if mouseDown and getgenv().SelectEquipped then
		local pos = UserInputService:GetMouseLocation()
		
		local lastPos = lastPos + Inset
		local Center = ((lastPos+ pos) * .5) - Inset
	
		local DistX = math.abs(lastPos.X - pos.X)  
		local DistY = math.abs(lastPos.Y - pos.Y)  
	
		selectionFrame.Position = UDim2.new(0, Center.X,0, Center.Y)
		selectionFrame.Size =  UDim2.new(0, DistX,0, DistY)
		
		selectionFrame.Visible = true
	end
end)

local UI = Material.Load({
	Title = "UltiTools",
	Style = 1,
	SizeX = 500,
	SizeY = 350,
	Theme = "Dark",
})

local Main = UI.New({
	Title = "Main"
})

local VIP_REQ = UI.New({
    Title = "VIP Required"
})

local GetSelect = Main.Button({
    Text = "Get select tool",
    Callback = function()
        local SelectTool = Instance.new("Tool", Player.Backpack)
        SelectTool.Name = "Select"
        SelectTool.RequiresHandle = false
        SelectTool.Equipped:Connect(function()
            getgenv().SelectEquipped = true
        end)
        
        SelectTool.Unequipped:Connect(function()
           	getgenv().SelectEquipped = false
        end)
    end
})

local LockSelected = VIP_REQ.Button({
	Text = "Toggle Lock Selected",
	Callback = function()
	    if Player.Backpack:FindFirstChild("VIP") or Player.Character:FindFirstChild("VIP") then
    	    for i,v in pairs(getgenv().Selected) do
    	        GetItem("VIP")
                game:GetService("ReplicatedStorage").ClientBridge.RequestPropertyChange:InvokeServer(v, "Locked", true)
                wait(0.1)
    	    end
    	    
    	    getgenv().Selected = {}
	    end
	end
})