

if SERVER then

function createPlayerStatusTable()
    sql.Query("CREATE TABLE IF NOT EXISTS player_status (steam_id TEXT PRIMARY KEY, lifepoints INTEGER, duelistlevel INTEGER, storyprogress INTEGER, status TEXT)")
end

function storePlayerStatus(steamID, lifepoints, duelistlevel, storyprogress, status)   -- store player's data. You can all this function from wherever you want with provided values
    local escapedSteamID = sql.SQLStr(steamID)
    local escapedstatus = sql.SQLStr(status)

    sql.Query("INSERT OR REPLACE INTO player_status (steam_id, lifepoints, duelistlevel, storyprogress, status) VALUES (" .. escapedSteamID .. ", " .. lifepoints .. ", " .. duelistlevel .. ", " .. storyprogress .. ", " .. escapedstatus .. ")")
end

createPlayerStatusTable()  -- call the function to create the player_status table

function getPlayerStatus(steamID)                                                                    -- get's all the player's data. this function can be used wherever if you provide player's steamID
    local escapedSteamID = sql.SQLStr(steamID)
    local result = sql.Query("SELECT * FROM player_status WHERE steam_id = " .. escapedSteamID)

    if result and #result == 1 then
        return {
            lifepoints = tonumber(result[1].lifepoints),
			duelistlevel = tonumber(result[1].duelistlevel),
			storyprogress = tonumber(result[1].storyprogress),
            status = result[1].status
        }
    else
        return nil
    end
end

util.AddNetworkString("playerStatusDataReceived")
function sendPlayerStatusDataToClients(lifepoints, duelistlevel, storyprogress, status) -- function used to send card data to clients
    net.Start("playerStatusDataReceived")  -- start a network message called PlayerDataReceived
	net.WriteUInt(lifepoints, 32) -- Use 32 bits to store 
	net.WriteUInt(duelistlevel, 32) -- Use 32 bits to store
	net.WriteUInt(storyprogress, 32) -- Use 32 bits to store
    net.WriteString(status)
    net.Broadcast()            -- finalize and send the data over the network
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------undecided section for now:-----------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

function GM:ShowHelp( ply )                  -- This function is called when the player presses F1 on their keyboard
    local plySteamID = ply:SteamID()
    
    -- Example custom status value
    local status = "waiting"

    -- Store the player's current status
    storePlayerStatus(plySteamID, 8000, 1, 1, status)    -- Store the player's current status

    -- Retrieve the player's current status
    local playerStatus = getPlayerStatus(plySteamID)
    if playerStatus then   -- if there was any data found
        local Status = playerStatus.status
		local Lifepoints = playerStatus.lifepoints
        print("The current status for Steam ID " .. plySteamID .. ": " .. Status)
		print("The current life points for Steam ID " .. plySteamID .. ": " .. Lifepoints)
	    sendPlayerStatusDataToClients(playerStatus.lifepoints, playerStatus.duelistlevel, playerStatus.storyprogress, playerStatus.status) -- start the net message defined earlier to send to all clients
    else
        print("No status found for Steam ID:", plySteamID)
    end
	    storePlayerData(plySteamID, "Blue-Eyes White Dragon", "Light", 8, "[Dragon] This legendary dragon is a powerful engine of destruction.", 3000, 2500, "none", "deck", "blueeyeswhitedragon.jpg")
    startDuel()
end

function GM:ShowTeam( ply )
  endTurn(ply)
end


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------Duel progression logic section:                -----------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------


function startDuel()                              -- function to be called when the duel starts
    local players = player.GetAll()               -- gets a table of all players currently on the server. (Should be always only 2 for this gamemode)

    if #players == 2 then                         -- if there are two players found
        local firstPlayerIndex = math.random(2) -- Randomly select 1 or 2 
        local firstPlayer = players[firstPlayerIndex] -- players[1] or players[2] depending on the math.random result would is used to select that player entity from the table 

        beginTurn(firstPlayer)        -- Begin the turn for the selected player (call the "beginTurn" function with that player entity)
        
        print("Duel started! Player", firstPlayer:Nick(), "goes first.")   -- tells the players who is going first
    else
        print("Cannot start the duel, there must be exactly two players on the server.") -- for if there aren't two players on the server
    end
end

local currentPlayer = nil



util.AddNetworkString("newTurn")
function beginTurn(ply)
    currentPlayer = ply               -- sets the currentPlayer var to the player who is calling a new turn
    updateRandomDeckEntryToHand(ply)  -- call the function from init.lua that draws one card from the deck to the hand if there is space
	
    local steamID = ply:SteamID()                -- gets players steam ID
    local escapedSteamID = sql.SQLStr(steamID)   -- needed for database queries
    sql.Query("UPDATE player_status SET status = 'drawphase' WHERE steam_id = " .. escapedSteamID) -- set the player's status to drawphase
     -- We use "drawphase" status for checking if they can play a monster card

    net.Start("newTurn")        -- send a net message
    net.WriteEntity(ply)        -- send the value of the current player entity
    net.Broadcast()	            -- and send it to any listening client
end

function endTurn(ply)                               -- the current player should be able to call this function to end his turn somehow, implement this later
    if ply == currentPlayer then                    -- 
        local opponent = getOpponent(ply)
        if opponent then
            beginTurn(opponent)
        end
    end
end


function setPlayerStatus(ply, newStatus)            -- called to update a players status with newStatus being the new status string
    local steamID = ply:SteamID()                 
    local escapedSteamID = sql.SQLStr(steamID)
    local updateQuery = "UPDATE player_status SET status = " .. sql.SQLStr(newStatus) .. " WHERE steam_id = " .. escapedSteamID
    local result = sql.Query(updateQuery)

    if not result then
        print("Failed to update player status")
    end
end
util.AddNetworkString("requestSetPlayerStatus")           -- cache this new network string
net.Receive("requestSetPlayerStatus", function(len, ply)  -- when the client sends this message to the server
    local newStatus = net.ReadString()                    -- reads the string from the client 
    setPlayerStatus(ply, newStatus)                       -- calls the function above with the newStatus parameter sent from client code
end)


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------Severside card placement check section:-----------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function canPlaceCard(ply)                           -- function that checks to determine if player can place a card in a zone
    local steamID = ply:SteamID()
    local escapedSteamID = sql.SQLStr(steamID)

    -- Get the player's status from the player_status table
    local result = sql.Query("SELECT status FROM player_status WHERE steam_id = " .. escapedSteamID)

    if result then                             -- if there is a result found then
        local playerStatus = result[1].status    -- make a var equal to the player's status value (datatype is string)

        
        if playerStatus == 'drawphase' then        -- if the player's status is 'drawphase'
	--	    sql.Query("UPDATE player_status SET status = 'mainphase' WHERE steam_id = " .. escapedSteamID)  -- change their status to "mainphase"	
            return true                       -- make this function return true meaning the player can place their selected card
        else
            print("Player is not in draw phase, cannot place a card.")
            return false   -- if they aren't in the drawphase then return false to stop them placing a card on the field
        end
    else
        print("Player status not found.")         -- this shouldn't happen, the player's status table should always exist
        return false
    end
end
util.AddNetworkString("requestCanPlaceCard")       -- set up some network strings to send later
util.AddNetworkString("receiveCanPlaceCard")       -- set up some network strings to send later
net.Receive("requestCanPlaceCard", function(len, ply)      -- net message from client that is recieved here if they try to place a card
    local canPlace = canPlaceCard(ply)                     -- creates a boolean that is set in the canPlaceCard function above
    net.Start("receiveCanPlaceCard")                       -- starts a net message with this name
    net.WriteBool(canPlace)                                -- writes the boolean result to send to client
    net.Send(ply)                                          -- sends the message to the client that requested it
end)



function canPlaceSpellOrTrapCard(ply, cardID)                           -- function that checks to determine if player can currently place a spell or trap card
    local steamID = ply:SteamID()
    local escapedSteamID = sql.SQLStr(steamID)
    local plyStatusResult = sql.Query("SELECT status FROM player_status WHERE steam_id = " .. escapedSteamID)     -- Get the player's status from the player_status table
	local cardData = sql.QueryRow("SELECT * FROM player_deck WHERE id = " .. cardID)                              -- get all the currently selected card's data from the player_deck table using it's cardID as an identifier
    if cardData and plyStatusResult and (cardData.cardtype == "Spell" or cardData.cardtype == "Trap") then        -- if all the data has been collected and the card is a spell or trap card
        local plyStatus = plyStatusResult[1].status                                                               -- get the player's status result
        if plyStatus == 'drawphase' or plyStatus == 'mainphase' then                                     -- if the player's status is 'drawphase' or 'mainphase'
            return true                                                                                    -- return true meaning they CAN place a spell or trap card
        else                                                                                -- the player's status was not "drawphase" or "mainphase" meaning it's not their turn
            print("It's not this player's turn, cannot place a spell or trap card.")       
            return false                                                                   -- so return false meaning they can't place a spell or trap
        end
    else                                    -- this should happen if the player status table isn't found for the current player or the card is a monster card
        print("Player status not found or card is a monster card.")                  
        return false                         -- so return false meaning they can't place a monster card in a spell or trap zone
    end
end
util.AddNetworkString("requestCanPlaceSpellOrTrapCard")
util.AddNetworkString("receiveCanPlaceSpellOrTrapCard")
net.Receive("requestCanPlaceSpellOrTrapCard", function(len, ply)      -- net message from client that is recieved here if they try to place a card in a spell/trap card zone
    local cardID = net.ReadUInt(32)                                   -- read the card's id field that has just been sent from the client
    local canPlaceSpellTrap = canPlaceSpellOrTrapCard(ply, cardID)    -- call the canPlaceSpellOrTrapCard function passing the player and their current card's id to to check
	
    net.Start("receiveCanPlaceSpellOrTrapCard")                      -- start a net message to send to the client the returned boolean deciding if they can place their card
    net.WriteBool(canPlaceSpellTrap) 
    net.Send(ply)                                                    -- send it to the relevant player
end)



end -- ends the if SERVER check

