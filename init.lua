AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( 'shared.lua' )

-- Function to create the cards table if it doesn't exist
function createPlayerDeckTable()
    sql.Query("CREATE TABLE IF NOT EXISTS player_deck (id INTEGER PRIMARY KEY AUTOINCREMENT, steam_id TEXT, cardname TEXT, cardtype TEXT, cardlevel INTEGER, carddesc TEXT, cardatk INTEGER, carddef INTEGER, effectfunc TEXT, cardstatus TEXT, cardimage TEXT)")
end

-- Function to store card data in this order. You can call this function from whereever you want if you provide the new card details.
function storePlayerData(steamID, cardname, cardtype, cardlevel, carddesc, cardatk, carddef, effectfunc, cardstatus, cardimage)
    local escapedSteamID = sql.SQLStr(steamID)
    local escapedcardname = sql.SQLStr(cardname)
	local escapedcardtype = sql.SQLStr(cardtype)
	local escapedcarddesc = sql.SQLStr(carddesc)
	local escapedeffectfunc = sql.SQLStr(effectfunc)
	local escapedcardstatus = sql.SQLStr(cardstatus)
    local escapedcardimage = sql.SQLStr(cardimage)

    sql.Query("INSERT INTO player_deck (steam_id, cardname, cardtype, cardlevel, carddesc, cardatk, carddef, effectfunc, cardstatus, cardimage) VALUES (" .. escapedSteamID .. ", " .. escapedcardname .. ", " .. escapedcardtype .. ", " .. cardlevel .. ", " .. escapedcarddesc .. ", " .. cardatk .. ", " .. carddef .. ", " .. escapedeffectfunc .. ", " .. escapedcardstatus .. ", " .. escapedcardimage .. ")")
end

-- Create the table if it doesn't exist
createPlayerDeckTable()


-- Function to retrieve player data based on specific column and value
function getPlayerDataByColumnValue(steamID, columnName, targetValue)
    local escapedSteamID = sql.SQLStr(steamID)
    local escapedColumnName = sql.SQLStr(columnName, true) -- Remove quotes around the identifier
    local escapedTargetValue

    if type(targetValue) == "string" then
        escapedTargetValue = sql.SQLStr(targetValue)
    else
        escapedTargetValue = tostring(targetValue)
    end

    local result = sql.Query("SELECT * FROM player_deck WHERE steam_id = " .. escapedSteamID .. " AND " .. escapedColumnName .. " = " .. escapedTargetValue)

    if result then
        local retrievedData = {}
        for _, row in ipairs(result) do
            table.insert(retrievedData, {
                cardname = row.cardname,
				cardtype = row.cardtype,
				carddesc = row.carddesc,
				effectfunc = row.effectfunc,
				cardstatus = row.cardstatus,
				cardimage = row.cardimage,
                cardlevel = tonumber(row.cardlevel),
                cardatk = tonumber(row.cardatk),
				carddef = tonumber(row.carddef),
            })
        end
        return retrievedData
    else
        return nil
    end
end


util.AddNetworkString("sendRandomDeckEntry")
-- Function to update 1 random entry with cardstatus "deck" to "hand" for the specified steamID. This is used to draw 1 card from the players deck
function updateRandomDeckEntryToHand(ply)
    local steamID = ply:SteamID()
    local escapedSteamID = sql.SQLStr(steamID)

    -- Retrieve all entries for the specified steamID with cardstatus value "deck"
    local result = sql.Query("SELECT * FROM player_deck WHERE steam_id = " .. escapedSteamID .. " AND cardstatus = 'deck'")
    
    if result and #result >= 1 then
        -- Select one random entry
        local randomIndex = math.random(#result)
        local randomEntry = result[randomIndex]

        -- Update the cardname value for the random entry
        sql.Query("UPDATE player_deck SET cardstatus = 'hand' WHERE id = " .. randomEntry.id)
        
        -- Send the random entry's data to the client
        net.Start("sendRandomDeckEntry")
        net.WriteString(randomEntry.cardimage)
        net.WriteUInt(tonumber(randomEntry.id), 32) -- Send the unique_id of the card
        net.Send(ply)
        
    else
        -- Implement duel loss for the current player
        print("No 'deck' entries found for Steam ID:", steamID)
        print("You have lost the duel:", steamID)
    end
end






util.AddNetworkString("PlayerDataReceived")
function sendPlayerDataToClients(cardname, cardtype, cardlevel, carddesc, cardatk, carddef, cardstatus, cardimage) -- function used to send card data to clients
    net.Start("PlayerDataReceived")  -- start a network message called PlayerDataReceived
    net.WriteString(cardname)
	net.WriteString(cardtype)
	net.WriteString(carddesc)
	net.WriteString(cardstatus)
	net.WriteString(cardimage)
    net.WriteUInt(cardlevel, 32) -- Use 32 bits to store 
	net.WriteUInt(cardatk, 32) -- Use 32 bits to store
	net.WriteUInt(carddef, 32) -- Use 32 bits to store
    net.Broadcast()            -- finalize and send the data over the network
end


function getOpponent(player)            -- used simply to get the current player whose turn it is not (boolean)
    local players = _G.player.GetAll()  -- same as normally getting a table of all players but for some reason _G is needed in this func
    for _, ply in ipairs(players) do    -- for all players found. Which will always be two in this gamemode
        if ply ~= player then           -- if the ply found is not the same as the player that called this function then
            return ply                  -- return the other player which will be the opponent in this case
        end
    end
    return nil                          -- otherwise return nil result
end

util.AddNetworkString("sendCardDataToOpponent")           -- set up these network strings
util.AddNetworkString("receiveCardDataFromOpponent")
net.Receive("sendCardDataToOpponent", function(len, ply)      -- when the player sends their current card data to the server for opponents use
    local zoneIndex = net.ReadUInt(32)                        -- read these card data vars sent in the code
    local imagePath = net.ReadString()
    local uniqueID = net.ReadUInt(32)
	local faceUp = net.ReadBool()
	
	local cardData = sql.QueryRow("SELECT * FROM player_deck WHERE id = " .. uniqueID) -- Get card data using the uniqueID
    if not cardData then
        print("Card data not found")
        return
    end

    local isSpellOrTrap = canPlaceSpellOrTrapCard(ply, uniqueID) -- Check if the card is a Spell or Trap card
    local zoneType = isSpellOrTrap and 1 or 0 -- If it's a Spell or Trap card, set zoneType to 1, otherwise set it to 0 (short hand if statement)


    local opponent = getOpponent(ply) -- calls the function located above this code that finds the player whose turn it currently IS NOT

    if opponent then                              -- if opponent found then
        net.Start("receiveCardDataFromOpponent")  -- time to send some data in a net message to the opponent about the current players card conditions
        net.WriteUInt(zoneIndex, 32)
        net.WriteString(imagePath)
        net.WriteUInt(uniqueID, 32)
		net.WriteBool(faceUp)
		net.WriteUInt(zoneType, 2) -- 2 bits are enough to represent 0 or 1. This is 0 or 1 depending on if it's a monster or spell/trap card
        net.Send(opponent)
    end
end)


util.AddNetworkString("sendDefModeToOpponent")           -- set up these network strings
util.AddNetworkString("receiveDefModeFromOpponent")
net.Receive("sendDefModeToOpponent", function(len, ply)
    local zoneIndex = net.ReadUInt(32)
    local imagePath = net.ReadString()
    local defMode = net.ReadBool()

    local opponent = getOpponent(ply)

    if opponent then
        net.Start("receiveDefModeFromOpponent")
		net.WriteUInt(zoneIndex, 32)
        net.WriteString(imagePath)
        net.WriteBool(defMode)
        net.Send(opponent)
    end	
end)



function GM:PlayerSpawn(ply)
  
    local plySteamID = ply:SteamID()   -- gets the players steam ID

    -- add these entries to the database.
	-- Format is steamID, cardname, cardtype, cardlevel, carddesc, cardatk, carddef, effectfunc, cardstatus, cardimage.
	-- Spell and trap cards most always have the "cardtype" of "Spell" or "Trap". Cards with effects store their function name in "effectfunc".  
    storePlayerData(plySteamID, "Blue-Eyes White Dragon", "Light", 8, "[Dragon] This legendary dragon is a powerful engine of destruction.", 3000, 2500, "none", "deck", "blueeyeswhitedragon.jpg")
    storePlayerData(plySteamID, "Dark Magician", "Dark", 7, "[Spellcaster] The ultimate wizard.", 2500, 2100, "none", "deck", "darkmagician.jpg")
    storePlayerData(plySteamID, "Man-Eater Bug", "Earth", 2, "[Insect/Effect] Choose and destroy one monster on the field.", 450, 600, "ManEaterBug()", "deck", "maneaterbug.jpg")
	storePlayerData(plySteamID, "Dark Hole", "Spell", 0, "Destroys all monsters on the field.", 0, 0, "DarkHole()", "deck", "darkhole.jpg")


    -- Update 1 random entry with cardstatus equal to "deck" to "hand" for the specified steamID. This is used to draw one card from the deck and add it to the hand
        updateRandomDeckEntryToHand(ply)
   
    -- Retrieve the array data
 local retrievedData = getPlayerDataByColumnValue(plySteamID, "cardlevel", 7)        -- get's all data from the database where for steamid equal to the current player, cardlevel is also equal to 7
                                                                                     -- you can modify "cardlevel" with any column name from the database and change it from 7 to search for a different value
                                                                                     -- remember to add quotation marks around the 7 if you want it to search for a string	value instead of a number value																				 
				 
				 
    if retrievedData then      -- if any data was found
        for _, data in ipairs(retrievedData) do      -- for the data found
		    sendPlayerDataToClients(data.cardname, data.cardtype, data.cardlevel, data.carddesc, data.cardatk, data.carddef, data.cardstatus, data.cardimage) -- start the net message defined earlier to send to all clients
           -- print("Card name:", data.cardname)    -- print the cardname data for every entry
          --  print("Card level:", data.cardlevel)  -- print the cardlevel data for every entry
         --   print("Card effect function:", data.effectfunc)   -- print the effect function string data for every entry
        end
    else
        print("No data found for Steam ID:", plySteamID)   -- this should never happen
    end
end




