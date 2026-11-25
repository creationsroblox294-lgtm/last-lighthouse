--!strict
-- Shared types.

export type Phase = "Calm" | "Warning" | "Storm" | "Dawn" | "Won"

export type PhaseInfo = {
	phase: Phase,
	currentStorm: number, -- the storm being prepared for / fought (1-100)
	stormsSurvived: number,
	endsAt: number, -- workspace:GetServerTimeNow() when this phase ends
	isGreatStorm: boolean,
	specialStorm: string?, -- "SilentFog" | "RedTide" | "GhostShip" | "CalmNight"
}

return {}
