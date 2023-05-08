function getOpponent(player)
    local players = player.GetHumans()
    for _, ply in ipairs(players) do
        if ply ~= player then
            return ply
        end
    end
    return nil
end
