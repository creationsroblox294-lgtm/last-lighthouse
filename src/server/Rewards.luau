--!strict
-- Rewards: a tiny hub so gameplay services can report things worth Brass without requiring
-- KeeperService (which would make a require loop). KeeperService listens and pays.
--   Rewards.Give(player, "Kill" | "Repair" | "Craft")

local Rewards = {}

local event = Instance.new("BindableEvent")
Rewards.Earned = event.Event

function Rewards.Give(player: Player, kind: string)
	event:Fire(player, kind)
end

return Rewards
