local Material = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kinlei/MaterialLua/master/Module.lua"))()
local DragControlIer = game:GetService("ReplicatedStorage").ClientBridge.DragControlIer
local Resize = game:GetService("ReplicatedStorage").ClientBridge.Resize --
local Seeder = Resize.Seeder --

local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService('GuiService')
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local clientSeeds = {}
local serverSeeds = {}
local increments = {}

Player.CharacterAdded:Connect(function()
    wait(1)
    for _, func in pairs(getgc()) do
        if type(func) == "function" and islclosure(func) then
            local source = getfenv(func).script
            local constants = getconstants(func)
            local nextInt = table.find(constants, "NextInteger")
            local seed = nextInt and constants[nextInt - 1]
            if seed and typeof(seed) == "number" then
                clientSeeds[source.Name] = seed
            elseif source and source:IsDescendantOf(game) then
                if source.Name == "Paint" then
                    increments["Color"] = function()
                        for i, v in pairs(debug.getupvalues(func)) do
                            if typeof(v) == "number" then
                                local increment = v + 1
                                debug.setupvalue(func, i, increment)
                                return increment
                            end
                        end
                    end
                else
                    for _, upvalue in pairs(getupvalues(func)) do
                        if typeof(upvalue) == "Random" then
                            serverSeeds[source.Name] = upvalue
                            break
                        end
                    end
                end
            end
        end
    end
end)

function GetSeed(property)
	return serverSeeds[property]:NextInteger(0, clientSeeds[property])
end

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

function Copy(part, cFrame)
    GetItem("Clone")
    local success, key, part = DragControlIer:InvokeServer("GetKey", part, true)
    if success then
        DragControlIer.Update:FireServer("Update", key, cFrame)
        DragControlIer.Update:FireServer("ClearKey", key)
    end
    StoreItems()
    return part
end

function Drag(part, cFrame)
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

local ColorForSelection = Color3.fromHSV(0,0,0)

local GUI = Instance.new("ScreenGui")
GUI.Parent = Player.PlayerGui
GUI.ResetOnSpawn = false

local selectionFrame = Instance.new("Frame", GUI)
selectionFrame.AnchorPoint = Vector2.new(0.5, 0.5)
selectionFrame.Transparency = 0.7
selectionFrame.BorderSizePixel = 0

spawn(function()
	while wait() do
		local t = 60
		local hue = tick() % t / t

		ColorForSelection = Color3.fromHSV(hue, 1, 1)
        selectionFrame.BackgroundColor3 = ColorForSelection
	end
end)

getgenv().Selected = {}
getgenv().Hidden = {}

spawn(function()
    while wait(0.1) do
        for i,v in pairs(getgenv().Selected) do
            local sel = Instance.new("SelectionBox")
            sel.Parent = v
            sel.Adornee = v
            sel.Color3 = ColorForSelection
            
            Debris:AddItem(sel, 0.11)
        end
    end
end)

local Inset = GuiService:GetGuiInset()
local Camera = workspace.CurrentCamera

local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0, 5)
uicorner.Parent = selectionFrame

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

-- Seeder.OnClientEvent:Connect(function(arg)
-- 	seed = Random.new(arg);
-- 	for v26 = 1, seed:NextInteger(5, 50) do
-- 		seed:NextInteger(1, 2);
-- 		getgenv().seed = seed
-- 	end
-- end) this was the 0 iq method (it worked doe)

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

local Essential = UI.New({
    Title = "Essential"
})

-- local Saving = UI.New({
--     Title = "Saving"
-- })

local GetSelect = Main.Button({
    Text = "Get select tool",
    Callback = function()
        local SelectTool = Instance.new("Tool", Player.Backpack)
        SelectTool.Name = "Select"
        SelectTool.RequiresHandle = false
        SelectTool.Equipped:Connect(function()
            getgenv().SelectEquipped = true
            getgenv().Selected = {}
        end)
        
        SelectTool.Unequipped:Connect(function()
           	getgenv().SelectEquipped = false
            getgenv().Selected = {}
        end)
    end
})

local GetSelect = Main.Button({
    Text = "Remove selection (in case something breaks)",
    Callback = function()
        getgenv().Selected = {}
    end
})

local LockSelected = VIP_REQ.Button({
	Text = "Toggle Lock Selected",
	Callback = function()
	    for i,v in pairs(getgenv().Selected) do
	        GetItem("VIP")
            game:GetService("ReplicatedStorage").ClientBridge.RequestPropertyChange:InvokeServer(v, "Locked", true)
            wait(0.2)
	    end
	    
	    getgenv().Selected = {}
	    StoreItems()
	end
})

Essential.Label({
    Text = "Properties"
})

local ChangePropertyName = Essential.TextField({
    Text = "Input Property Name"
})

local ChangePropertyValue = Essential.TextField({
    Text = "Input Property Value"
})

local ChangeProperty = Essential.Button({
    Text = "Change Property (Need VIP to change VIP properties)",
    Callback = function()

        GetItem("Properties")
        GetItem("VIP")
        
        for i,v in pairs(getgenv().Selected) do
            prop_value = nil
            local success, res = pcall(function()
                prop_value = tonumber(ChangePropertyValue:GetText())
            end)
            if not success then
                prop_value = ChangePropertyValue:GetText() == "true"
            end

            pcall(function()
                game:GetService("ReplicatedStorage").ClientBridge.RequestPropertyChange:InvokeServer(v, ChangePropertyName:GetText(), prop_value)
            end)
            wait(0.2)
        end
        
        getgenv().Selected = {}
        StoreItems()
    end
})

Players:Chat("re")