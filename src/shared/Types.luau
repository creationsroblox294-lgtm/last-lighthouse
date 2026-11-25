--!strict
-- Shared types.

export type Phase = "Calm" | "Warning" | "Storm" | "Dawn" | "Won" | "Lost"

export type PhaseInfo = {
	phase: Phase,
	currentStorm: number, -- the storm being prepared for / fought
	stormsSurvived: number,
	endsAt: number, -- workspace:GetServerTimeNow() when this phase ends (0 = no timer)
	isGreatStorm: boolean,
	specialStorm: string?, -- "SilentFog" | "RedTide" | "GhostShip" | "CalmNight"
}

export type ResourceKind = "Wood" | "Scrap" | "Oil" | "Fish" | "WhaleOil"

return {}
