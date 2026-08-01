--[[
 .____                  ________ ___.    _____                           __                
 |    |    __ _______   \_____  \\_ |___/ ____\_ __  ______ ____ _____ _/  |_  ___________ 
 |    |   |  |  \__  \   /   |   \| __ \   __\  |  \/  ___// ___\\__  \\   __\/  _ \_  __ \
 |    |___|  |  // __ \_/    |    \ \_\ \  | |  |  /\___ \\  \___ / __ \|  | (  <_> )  | \/
 |_______ \____/(____  /\_______  /___  /__| |____//____  >\___  >____  /__|  \____/|__|   
         \/          \/         \/    \/                \/     \/     \/                   
          \_Welcome to LuaObfuscator.com   (Alpha 0.10.9) ~  Much Love, Ferib 

]]--

local Players = game:GetService("Players");
local RunService = game:GetService("RunService");
local UserInputService = game:GetService("UserInputService");
local LocalPlayer = Players.LocalPlayer;
local State = {ESP=false,Aimbot=false,BodyPart="Head",FOV=150,Smooth=0.3,TeamCheck=true,WallCheck=false,Prediction=false,PredictionAmount=0.1};
local SETTINGS = {ESPColor=Color3.fromRGB(0, 255, 200),TextColor=Color3.fromRGB(255, 255, 255),ArrowColor=Color3.fromRGB(255, 0, 0)};
local Camera = workspace.CurrentCamera;
local fovCircle = nil;
local hudText = nil;
local EspObjects = {};
local ArrowIndicators = {};
local aimbotConnection = nil;
local wallEspConnection = nil;
local menuCreated = false;
local menuFrame = nil;
local floatingButton = nil;
local function InitializeDrawing()
	if fovCircle then
		return;
	end
	pcall(function()
		fovCircle = Drawing.new("Circle");
		fovCircle.Visible = false;
		fovCircle.Radius = State.FOV;
		fovCircle.Color = Color3.fromRGB(255, 0, 0);
		fovCircle.Thickness = 1;
		fovCircle.Filled = false;
		fovCircle.NumSides = 60;
		fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2);
		Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if fovCircle then
				fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2);
			end
		end);
		hudText = Drawing.new("Text");
		hudText.Size = 18;
		hudText.Color = Color3.fromRGB(0, 255, 0);
		hudText.Center = false;
		hudText.Outline = true;
		hudText.OutlineColor = Color3.fromRGB(0, 0, 0);
		hudText.Position = Vector2.new(10, 30);
		hudText.Text = "";
		hudText.Visible = true;
	end);
end
local function GetTarget()
	if not LocalPlayer.Character then
		return nil;
	end
	local character = LocalPlayer.Character;
	local rootPart = character:FindFirstChild("HumanoidRootPart");
	if not rootPart then
		return nil;
	end
	local myPos = rootPart.Position;
	local bestTarget = nil;
	local bestDist = math.huge;
	for _, player in ipairs(Players:GetPlayers()) do
		if ((player ~= LocalPlayer) and player.Character) then
			local targetChar = player.Character;
			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart");
			local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid");
			if (targetRoot and targetHumanoid and (targetHumanoid.Health > 0)) then
				if (State.TeamCheck and (player.Team == LocalPlayer.Team)) then
					continue;
				end
				if State.WallCheck then
					local ray = Ray.new(myPos, (targetRoot.Position - myPos).Unit * 500);
					local hit, pos = workspace:FindPartOnRay(ray, character);
					if (hit and not hit:IsDescendantOf(targetChar)) then
						continue;
					end
				end
				local screenPos, onScreen = Camera:WorldToViewportPoint(targetRoot.Position);
				if onScreen then
					local center = Camera.ViewportSize / 2;
					local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude;
					if ((distFromCenter < State.FOV) and (distFromCenter < bestDist)) then
						bestDist = distFromCenter;
						bestTarget = player;
					end
				end
			end
		end
	end
	return bestTarget;
end
local function GetBodyPart(player, partName)
	if (partName == "Random") then
		local parts = {"Head","UpperTorso","LowerTorso","LeftArm","RightArm","LeftLeg","RightLeg"};
		partName = parts[math.random(#parts)];
	end
	local char = player.Character;
	if not char then
		return nil;
	end
	local part = char:FindFirstChild(partName);
	if (part and part:IsA("BasePart")) then
		return part;
	end
	for _, child in ipairs(char:GetChildren()) do
		if (child:IsA("BasePart") and string.find(child.Name, partName)) then
			return child;
		end
	end
	return char:FindFirstChild("HumanoidRootPart");
end
local function StartAimbot()
	if aimbotConnection then
		aimbotConnection:Disconnect();
	end
	aimbotConnection = RunService.RenderStepped:Connect(function()
		if not State.Aimbot then
			return;
		end
		pcall(function()
			local target = GetTarget();
			if target then
				local part = GetBodyPart(target, State.BodyPart);
				if part then
					local camPos = Camera.CFrame.Position;
					local targetPos = part.Position;
					if State.Prediction then
						local velocity = (target.Character:FindFirstChild("HumanoidRootPart") and target.Character.HumanoidRootPart.Velocity) or Vector3.new();
						targetPos = targetPos + (velocity * State.PredictionAmount);
					end
					local direction = (targetPos - camPos).Unit;
					local targetCF = CFrame.lookAt(camPos, camPos + direction);
					Camera.CFrame = Camera.CFrame:Lerp(targetCF, State.Smooth);
				end
			end
		end);
	end);
end
local function StopAimbot()
	if aimbotConnection then
		aimbotConnection:Disconnect();
		aimbotConnection = nil;
	end
end
local function UpdateESP()
	for _, obj in pairs(EspObjects) do
		pcall(function()
			obj:Destroy();
		end);
	end
	EspObjects = {};
	if not State.ESP then
		return;
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if ((player ~= LocalPlayer) and player.Character) then
			local char = player.Character;
			local root = char:FindFirstChild("HumanoidRootPart");
			local head = char:FindFirstChild("Head");
			if (root and head) then
				local box = Drawing.new("Square");
				box.Thickness = 2;
				box.Color = SETTINGS.ESPColor;
				box.Filled = false;
				table.insert(EspObjects, box);
				local nameTag = Drawing.new("Text");
				nameTag.Text = player.Name;
				nameTag.Color = SETTINGS.TextColor;
				nameTag.Size = 16;
				nameTag.Center = true;
				nameTag.Outline = true;
				nameTag.OutlineColor = Color3.new(0, 0, 0);
				table.insert(EspObjects, nameTag);
				local connection;
				connection = RunService.RenderStepped:Connect(function()
					if not State.ESP then
						box.Visible = false;
						nameTag.Visible = false;
						return;
					end
					pcall(function()
						local pos, onScreen = Camera:WorldToViewportPoint(root.Position);
						if onScreen then
							local scale = 3 / (pos.Z + 1);
							local size = Vector2.new(200 * scale, 250 * scale);
							box.Position = Vector2.new(pos.X - (size.X / 2), pos.Y - (size.Y / 2));
							box.Size = size;
							box.Visible = true;
							nameTag.Position = Vector2.new(pos.X, (pos.Y - (size.Y / 2)) - 15);
							nameTag.Visible = true;
						else
							box.Visible = false;
							nameTag.Visible = false;
						end
					end);
				end);
				table.insert(EspObjects, connection);
			end
		end
	end
end
local function DrawArrow(player)
	if not player.Character then
		return;
	end
	local root = player.Character:FindFirstChild("HumanoidRootPart");
	if not root then
		return;
	end
	local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position);
	local center = Camera.ViewportSize / 2;
	local dir = (Vector2.new(screenPos.X, screenPos.Y) - center).Unit;
	local angle = math.atan2(dir.Y, dir.X);
	if onScreen then
		return;
	end
	local radius = math.min(Camera.ViewportSize.X, Camera.ViewportSize.Y) * 0.45;
	local posX = center.X + (math.cos(angle) * radius);
	local posY = center.Y + (math.sin(angle) * radius);
	local indicator = ArrowIndicators[player];
	if not indicator then
		indicator = Drawing.new("Triangle");
		indicator.Thickness = 2;
		indicator.Color = SETTINGS.ArrowColor;
		indicator.Filled = true;
		ArrowIndicators[player] = indicator;
	end
	local size = 12;
	local p1 = Vector2.new(posX + (math.cos(angle) * size), posY + (math.sin(angle) * size));
	local p2 = Vector2.new(posX + (math.cos(angle + 2.5) * size), posY + (math.sin(angle + 2.5) * size));
	local p3 = Vector2.new(posX + (math.cos(angle - 2.5) * size), posY + (math.sin(angle - 2.5) * size));
	indicator.PointA = p1;
	indicator.PointB = p2;
	indicator.PointC = p3;
	indicator.Visible = State.ESP;
end
local function StartWallEsp()
	if wallEspConnection then
		wallEspConnection:Disconnect();
	end
	wallEspConnection = RunService.RenderStepped:Connect(function()
		if not State.ESP then
			for _, ind in pairs(ArrowIndicators) do
				ind.Visible = false;
			end
			return;
		end
		pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if (player ~= LocalPlayer) then
					DrawArrow(player);
				end
			end
			for player, ind in pairs(ArrowIndicators) do
				if (not player.Parent or not player.Character) then
					ind:Remove();
					ArrowIndicators[player] = nil;
				end
			end
		end);
	end);
end
local hudConnection;
local function StartHUD()
	if hudConnection then
		hudConnection:Disconnect();
	end
	hudConnection = RunService.RenderStepped:Connect(function()
		if not hudText then
			return;
		end
		pcall(function()
			if State.Aimbot then
				local target = GetTarget();
				if target then
					local part = GetBodyPart(target, State.BodyPart);
					if part then
						local dist = (Camera.CFrame.Position - part.Position).Magnitude;
						hudText.Text = string.format("🎯 %s | %s | %.1fm", target.Name, State.BodyPart, dist);
						hudText.Color = Color3.fromRGB(0, 255, 0);
					else
						hudText.Text = "🎯 Nenhum alvo";
						hudText.Color = Color3.fromRGB(255, 255, 0);
					end
				else
					hudText.Text = "🎯 Nenhum alvo";
					hudText.Color = Color3.fromRGB(255, 255, 0);
				end
			else
				hudText.Text = "";
			end
		end);
	end);
end
local function CreateMenu()
	if menuCreated then
		return;
	end
	menuCreated = true;
	local screenGui = Instance.new("ScreenGui");
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui");
	screenGui.Name = "NoNameHubGUI";
	local floatBtn = Instance.new("ImageButton");
	floatBtn.Size = UDim2.new(0, 60, 0, 60);
	floatBtn.Position = UDim2.new(0.9, -30, 0.85, -30);
	floatBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 60);
	floatBtn.BackgroundTransparency = 0.2;
	floatBtn.BorderSizePixel = 0;
	floatBtn.Image = "rbxassetid://3570695787";
	floatBtn.ImageColor3 = Color3.fromRGB(255, 255, 255);
	floatBtn.ImageTransparency = 0.2;
	floatBtn.Parent = screenGui;
	floatingButton = floatBtn;
	local floatCorner = Instance.new("UICorner");
	floatCorner.CornerRadius = UDim.new(1, 0);
	floatCorner.Parent = floatBtn;
	local floatShadow = Instance.new("ImageLabel");
	floatShadow.Size = UDim2.new(1, 8, 1, 8);
	floatShadow.Position = UDim2.new(0, -4, 0, -4);
	floatShadow.BackgroundTransparency = 1;
	floatShadow.Image = "rbxassetid://3570695787";
	floatShadow.ImageColor3 = Color3.fromRGB(0, 0, 0);
	floatShadow.ImageTransparency = 0.6;
	floatShadow.Parent = floatBtn;
	local shadowCorner = Instance.new("UICorner");
	shadowCorner.CornerRadius = UDim.new(1, 0);
	shadowCorner.Parent = floatShadow;
	local dragging = false;
	local dragStart = nil;
	local startPos = nil;
	floatBtn.InputBegan:Connect(function(input)
		if ((input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch)) then
			dragging = true;
			dragStart = input.Position;
			startPos = floatBtn.Position;
		end
	end);
	floatBtn.InputEnded:Connect(function(input)
		if ((input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch)) then
			dragging = false;
		end
	end);
	UserInputService.InputChanged:Connect(function(input)
		if (dragging and ((input.UserInputType == Enum.UserInputType.MouseMovement) or (input.UserInputType == Enum.UserInputType.Touch))) then
			local delta = input.Position - dragStart;
			floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y);
		end
	end);
	local frame = Instance.new("Frame");
	frame.Size = UDim2.new(0, 200, 0, 220);
	frame.Position = UDim2.new(0.5, -100, 0.5, -110);
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 40);
	frame.BackgroundTransparency = 0.15;
	frame.BorderSizePixel = 0;
	frame.Draggable = true;
	frame.Active = true;
	frame.Visible = false;
	frame.Parent = screenGui;
	menuFrame = frame;
	local corner = Instance.new("UICorner");
	corner.CornerRadius = UDim.new(0, 12);
	corner.Parent = frame;
	local title = Instance.new("TextLabel");
	title.Size = UDim2.new(1, 0, 0, 35);
	title.Position = UDim2.new(0, 0, 0, 0);
	title.BackgroundTransparency = 1;
	title.Text = "✦ NoNameHub ✦";
	title.TextColor3 = Color3.fromRGB(255, 215, 0);
	title.TextScaled = true;
	title.Font = Enum.Font.GothamBold;
	title.Parent = frame;
	local divider = Instance.new("Frame");
	divider.Size = UDim2.new(0.8, 0, 0, 1);
	divider.Position = UDim2.new(0.1, 0, 0, 35);
	divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
	divider.BackgroundTransparency = 0.4;
	divider.Parent = frame;
	local espBtn = Instance.new("TextButton");
	espBtn.Size = UDim2.new(0.8, 0, 0, 32);
	espBtn.Position = UDim2.new(0.1, 0, 0, 45);
	espBtn.Text = "📡 ESP: OFF";
	espBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80);
	espBtn.TextColor3 = Color3.fromRGB(255, 255, 255);
	espBtn.Font = Enum.Font.GothamSemibold;
	espBtn.Parent = frame;
	local espCorner = Instance.new("UICorner");
	espCorner.CornerRadius = UDim.new(0, 8);
	espCorner.Parent = espBtn;
	local aimBtn = Instance.new("TextButton");
	aimBtn.Size = UDim2.new(0.8, 0, 0, 32);
	aimBtn.Position = UDim2.new(0.1, 0, 0, 85);
	aimBtn.Text = "🎯 Aimbot: OFF";
	aimBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80);
	aimBtn.TextColor3 = Color3.fromRGB(255, 255, 255);
	aimBtn.Font = Enum.Font.GothamSemibold;
	aimBtn.Parent = frame;
	local aimCorner = Instance.new("UICorner");
	aimCorner.CornerRadius = UDim.new(0, 8);
	aimCorner.Parent = aimBtn;
	local bodyLabel = Instance.new("TextLabel");
	bodyLabel.Size = UDim2.new(0.8, 0, 0, 20);
	bodyLabel.Position = UDim2.new(0.1, 0, 0, 125);
	bodyLabel.BackgroundTransparency = 1;
	bodyLabel.Text = "Parte: " .. State.BodyPart;
	bodyLabel.TextColor3 = Color3.fromRGB(200, 200, 200);
	bodyLabel.TextScaled = true;
	bodyLabel.Font = Enum.Font.Gotham;
	bodyLabel.Parent = frame;
	local bodyBtn = Instance.new("TextButton");
	bodyBtn.Size = UDim2.new(0.8, 0, 0, 25);
	bodyBtn.Position = UDim2.new(0.1, 0, 0, 145);
	bodyBtn.Text = "Mudar Parte";
	bodyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 70);
	bodyBtn.TextColor3 = Color3.fromRGB(255, 255, 255);
	bodyBtn.Font = Enum.Font.GothamSemibold;
	bodyBtn.Parent = frame;
	local bodyCorner = Instance.new("UICorner");
	bodyCorner.CornerRadius = UDim.new(0, 6);
	bodyCorner.Parent = bodyBtn;
	local partOptions = {"Head","UpperTorso","LowerTorso","LeftArm","RightArm","LeftLeg","RightLeg","Random"};
	local partIndex = 1;
	bodyBtn.MouseButton1Click:Connect(function()
		partIndex = (partIndex % #partOptions) + 1;
		State.BodyPart = partOptions[partIndex];
		bodyLabel.Text = "Parte: " .. State.BodyPart;
	end);
	local version = Instance.new("TextLabel");
	version.Size = UDim2.new(1, 0, 0, 20);
	version.Position = UDim2.new(0, 0, 0, 200);
	version.BackgroundTransparency = 1;
	version.Text = "v2.0 • mobile";
	version.TextColor3 = Color3.fromRGB(200, 200, 200);
	version.TextScaled = true;
	version.Font = Enum.Font.Gotham;
	version.TextTransparency = 0.5;
	version.Parent = frame;
	if UserInputService.TouchEnabled then
		frame.Size = UDim2.new(0, 220, 0, 250);
		frame.Position = UDim2.new(0.5, -110, 0.5, -125);
		title.Size = UDim2.new(1, 0, 0, 45);
		divider.Position = UDim2.new(0.1, 0, 0, 45);
		espBtn.Size = UDim2.new(0.8, 0, 0, 40);
		espBtn.Position = UDim2.new(0.1, 0, 0, 55);
		aimBtn.Size = UDim2.new(0.8, 0, 0, 40);
		aimBtn.Position = UDim2.new(0.1, 0, 0, 100);
		bodyLabel.Position = UDim2.new(0.1, 0, 0, 150);
		bodyBtn.Size = UDim2.new(0.8, 0, 0, 35);
		bodyBtn.Position = UDim2.new(0.1, 0, 0, 170);
		version.Position = UDim2.new(0, 0, 0, 220);
	end
	espBtn.MouseButton1Click:Connect(function()
		State.ESP = not State.ESP;
		espBtn.Text = (State.ESP and "📡 ESP: ON") or "📡 ESP: OFF";
		espBtn.BackgroundColor3 = (State.ESP and Color3.fromRGB(0, 150, 80)) or Color3.fromRGB(50, 50, 80);
		UpdateESP();
		StartWallEsp();
	end);
	aimBtn.MouseButton1Click:Connect(function()
		State.Aimbot = not State.Aimbot;
		aimBtn.Text = (State.Aimbot and "🎯 Aimbot: ON") or "🎯 Aimbot: OFF";
		aimBtn.BackgroundColor3 = (State.Aimbot and Color3.fromRGB(0, 150, 80)) or Color3.fromRGB(50, 50, 80);
		if State.Aimbot then
			StartAimbot();
		else
			StopAimbot();
		end
	end);
	floatBtn.MouseButton1Click:Connect(function()
		frame.Visible = not frame.Visible;
	end);
end
local function Initialize()
	if not LocalPlayer.Character then
		LocalPlayer.CharacterAdded:Wait();
	end
	repeat
		wait();
	until workspace.CurrentCamera 
	Camera = workspace.CurrentCamera;
	InitializeDrawing();
	StartHUD();
	CreateMenu();
	print("✅ NoNameHub carregado! Toque na bola para abrir/fechar o menu.");
end
task.wait(0.5);
pcall(Initialize);
