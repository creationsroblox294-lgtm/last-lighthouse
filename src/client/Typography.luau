--!strict
-- Typography: one type system for every screen, instead of Roblox's default Gotham.
--   Headings / big numbers:  Merriweather Heavy (a sturdy nautical serif)
--   Buttons / labels:        Builder Sans Bold / SemiBold
--   Body text:               Builder Sans Medium
-- Controllers keep writing Enum.Font.Gotham* (and FredokaOne for the old heading style); this
-- maps each to the right FontFace as text appears, in PlayerGui and on in-world signs and
-- nameplates. Fonts picked on purpose (Merriweather, Fondamento, Creepster...) are left alone.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Typography = {}

local SERIF = "rbxasset://fonts/families/Merriweather.json"
local SANS = "rbxasset://fonts/families/BuilderSans.json"

Typography.Heading = Font.new(SERIF, Enum.FontWeight.Heavy)
Typography.Bold = Font.new(SANS, Enum.FontWeight.Bold)
Typography.SemiBold = Font.new(SANS, Enum.FontWeight.SemiBold)
Typography.Body = Font.new(SANS, Enum.FontWeight.Medium)

local MAP: { [Enum.Font]: Font } = {
	[Enum.Font.GothamBlack] = Typography.Heading,
	[Enum.Font.FredokaOne] = Typography.Heading,
	[Enum.Font.GothamBold] = Typography.Bold,
	[Enum.Font.GothamSemibold] = Typography.SemiBold,
	[Enum.Font.GothamMedium] = Typography.Body,
	[Enum.Font.Gotham] = Typography.Body,
	[Enum.Font.SourceSansBold] = Typography.Bold,
	[Enum.Font.SourceSansSemibold] = Typography.SemiBold,
	[Enum.Font.SourceSans] = Typography.Body,
}

local function apply(o: Instance)
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		local face = MAP[o.Font]
		if face then
			o.FontFace = face
		end
	end
end

local function watch(root: Instance)
	for _, d in root:GetDescendants() do
		apply(d)
	end
	root.DescendantAdded:Connect(function(d)
		apply(d)
		-- text made in code often gets its font a moment after it's parented
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			task.defer(apply, d)
		end
	end)
end

function Typography.Start()
	watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	watch(Workspace)
end

return Typography
