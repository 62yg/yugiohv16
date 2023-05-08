
------------------------------------------------------------- This section is just for debugging stuff and gives examples of receiving data from server: ---------------------
net.Receive("PlayerDataReceived", function()
    local cardname = net.ReadString()
	local cardtype = net.ReadString() 
	local carddesc = net.ReadString()
	local cardstatus = net.ReadString()
	local cardimage = net.ReadString()
    local cardlevel = net.ReadUInt(32) -- Use 32 bits to read the player level
	local cardatk = net.ReadUInt(32) -- Use 32 bits to read the player level
	local carddef = net.ReadUInt(32) -- Use 32 bits to read the player level

 --   print("Player data received:")
 --   print("Card name:", cardname)
 --	  print("Card type:", cardtype)
 --   print("Card description:", carddesc)
 --   print("Card location status:", cardstatus)
 --	  print("Card image path:", cardimage)
 --   print("Card stars:", cardlevel)
 --   print("Card attack points:", cardatk)
 --   print("Card defence points:", carddef)
end)

net.Receive("playerStatusDataReceived", function()
    local lifepoints = net.ReadUInt(32) -- Use 32 bits to read the player level
	local duelistlevel = net.ReadUInt(32) -- Use 32 bits to read the player level
	local storyprogress = net.ReadUInt(32) -- Use 32 bits to read the player level
    local status = net.ReadString()

   -- print("Player status data received:")
   -- print("Current life points:", lifepoints)
   -- print("Duelist level:", duelistlevel)
   -- print("Story Progression %:", storyprogress)
   -- print("Current player status:", status)
end)

------------------------------------------------------------- this section is for drawing all the card zones------------------------------------------------------------
local function createImageButtons()                                 -- this function is used to create all the zones, each consisting of 5 spaces
    local panelWidth, panelHeight = 190, 205
    local gap = 10
    local startY = 5
    local startX = (ScrW() - (5 * panelWidth + (5 - 1) * gap)) / 2

    local parentPanel = vgui.Create("DFrame")   -- this is the derma frame that all the card spaces are parented to, it can't be closed by the player
    parentPanel:SetSize(ScrW(), ScrH())
    parentPanel:SetPos(0, 0)
    parentPanel:SetTitle("")
    parentPanel:SetVisible(true)
    parentPanel:SetDraggable(false)
    parentPanel:ShowCloseButton(false)
    parentPanel:MakePopup()

    local Hand, PlayerMonsters, PlayerSpellsTraps, OpponentMonsters, OpponentSpellsTraps = {}, {}, {}, {}, {}  -- just defines these tables for later

    local function createCardZone(zone, y)                            -- function used to create one zone of 5 spaces it accepts the type of zone and its position on y axis
        for i = 1, 5 do                                                    -- for 5 different objects
            local imageButton = vgui.Create("DImageButton", parentPanel)   -- create a button and parent it to the derma panel behind
            imageButton:SetPos(startX + (i - 1) * (panelWidth + gap), y)   -- set the position of that button  
            imageButton:SetSize(panelWidth, panelHeight)                   -- set the dimensions
            imageButton:SetImage("vgui/white")                             -- set the space to the default white background for when it is unoccupied by a card
            zone[i] = imageButton
        end
    end

    -- add any extra zones here if you need them, incrementing the number 
	createCardZone(Hand, startY + 4 * (panelHeight + gap))
    createCardZone(PlayerMonsters, startY + 2 * (panelHeight + gap))
    createCardZone(PlayerSpellsTraps, startY + 3 * (panelHeight + gap))
    createCardZone(OpponentMonsters, startY + 1 * (panelHeight + gap))
    createCardZone(OpponentSpellsTraps, startY)

	
    return Hand, PlayerMonsters, PlayerSpellsTraps, OpponentMonsters, OpponentSpellsTraps
end

local Hand, PlayerMonsters, PlayerSpellsTraps, OpponentMonsters, OpponentSpellsTraps = createImageButtons()


--------------------------------------------This section of code is for when a player clicks on cards:----------------------------------------------
local selectedCard

local function selectCard(imageButton)  -- Makes the clicked card highlighted
    if selectedCard then
        selectedCard:SetColor(Color(255, 255, 255, 255))  -- Reset the color of the previously selected card
    end
    selectedCard = imageButton
    imageButton:SetColor(Color(128, 255, 128, 255))  -- Highlight the selected card
end

function sendCardDataToOpponent(zoneIndex, imagePath, uniqueID, faceUp)
    net.Start("sendCardDataToOpponent")
    net.WriteUInt(zoneIndex, 32)
    net.WriteString(imagePath)
    net.WriteUInt(uniqueID, 32)
    net.WriteBool(faceUp)
    net.SendToServer()
end

              
local function placeCardInZone(zone, newImage, faceUp)      -- used to place monster card data from the players hand into a monster zone space         
    if selectedCard then
        local zoneIndex = table.KeyFromValue(PlayerMonsters, zone)
        if zoneIndex then
            sendCardDataToOpponent(zoneIndex, newImage, selectedCard.uniqueID, faceUp)
        end

        zone:SetImage(newImage)
        zone.uniqueID = selectedCard.uniqueID
		zone.faceUp = faceUp

        selectedCard:SetImage("vgui/white")
        selectedCard.uniqueID = nil
        selectedCard:SetColor(Color(255, 255, 255, 255))
        selectedCard = nil
    end
end


local function placeCardInSpellTrapZone(zone)                 
    if selectedCard then
        local zoneIndex = table.KeyFromValue(PlayerSpellsTraps, zone)
        if zoneIndex then
            sendCardDataToOpponent(zoneIndex, selectedCard:GetImage(), selectedCard.uniqueID)
        end

        zone:SetImage(selectedCard:GetImage())
        zone.uniqueID = selectedCard.uniqueID
        selectedCard:SetImage("vgui/white")
        selectedCard.uniqueID = nil
        selectedCard:SetColor(Color(255, 255, 255, 255))
        selectedCard = nil
    end
end


-- Assign click events for the hand and player's monster zone and spell and trap zone
for _, cardInHand in ipairs(Hand) do
    cardInHand.DoClick = function()                 -- creates a function when a card in the players hand is clicked
        if not cardInHand.uniqueID then return end  -- if the card in the hand doesn't have a uniqueID (meaning there is no card in that space) then do nothing
        selectCard(cardInHand)                      -- otherwise call the selectCard function for that space
    end
end

for _, playerMonsterZone in ipairs(PlayerMonsters) do -- for the spaces in the monster zone of the player
    playerMonsterZone.DoClick = function()            -- when a space in the monster zone is clicked 
	  requestCanPlaceCard(function(canPlace)          -- asks the server if we can place a monster card
	    requestCanPlaceSpellOrTrapCard(selectedCard.uniqueID, function(canPlaceSpellTrap) -- runs the net messages to ask the server if the player can place it as a spell/trap this should be false for monster cards
	       if canPlace and not canPlaceSpellTrap then
            createFaceUpDownPanel(playerMonsterZone)
            local clientPlayer = LocalPlayer()
			net.Start("requestSetPlayerStatus")          -- send a net message to the server called This
            net.WriteString("mainphase")                 -- and writes the string: mainphase. (This will be used to set player's status)
            net.SendToServer()                           -- sends to the server code (look in shared.lua for the receiving function)
		  end
	    end)	
	  end)
    end
    playerMonsterZone.DoRightClick = function()
        if playerMonsterZone.uniqueID then
		            local zoneIndex = table.KeyFromValue(PlayerMonsters, playerMonsterZone) 
            createMonsterActionPanel(playerMonsterZone, zoneIndex)  -- Pass zoneIndex here
        end
    end
end
	
	

for _, playerSpellTrapZone in ipairs(PlayerSpellsTraps) do -- for the spaces in the monster zone of the player
    playerSpellTrapZone.DoClick = function()            -- when a space in the monster zone is clicked 
	     requestCanPlaceSpellOrTrapCard(selectedCard.uniqueID, function(canPlaceSpellTrap) -- runs the net messages to ask the server if the player can place it as a spell/trap
	       if canPlaceSpellTrap then                                 
            placeCardInSpellTrapZone(playerSpellTrapZone) -- run the function to set the clicked space's data to the card that came from the hand if it's a spell/trap card
           end
	     end)
    end
end



-------------------------------------------This section is for functions creating small derma panel menus and their functions:-------------------------------------------------------------------
function createFaceUpDownPanel(zone)
    local faceUpDownPanel = vgui.Create("DFrame") -- Parent the faceUpDownPanel to the overlay
      faceUpDownPanel:SetSize(ScrW(), ScrH())
    faceUpDownPanel:SetTitle("Choose Card Orientation")
	faceUpDownPanel:SetVisible(true)
    faceUpDownPanel:SetDraggable(false)
    faceUpDownPanel:Center()
	faceUpDownPanel:ShowCloseButton(false)
    faceUpDownPanel:MakePopup()


    local faceUpButton = vgui.Create("DButton", faceUpDownPanel)
    faceUpButton:SetSize(150, 40)
     faceUpButton:SetPos(faceUpDownPanel:GetWide() / 2 - faceUpButton:GetWide() - 20, faceUpDownPanel:GetTall() / 2)
    faceUpButton:SetText("Set Face Up")
    faceUpButton.DoClick = function()
        local newImage = setCardFaceUp(zone, selectedCard:GetImage())
        placeCardInZone(zone, newImage, true)
        faceUpDownPanel:Close()
    end

    local faceDownButton = vgui.Create("DButton", faceUpDownPanel)
    faceDownButton:SetSize(150, 40)
    faceDownButton:SetPos(faceUpDownPanel:GetWide() / 2 + 20, faceUpDownPanel:GetTall() / 2)
    faceDownButton:SetText("Set Face Down")
    faceDownButton.DoClick = function()
        local newImage = setCardFaceDown(zone, selectedCard:GetImage())
        placeCardInZone(zone, newImage, false)
        faceUpDownPanel:Close()
    end
end


function setCardFaceUp(zone, cardImage)
    -- Set the card face-up	
    zone.faceUp = true
    -- Return the original card image
    return cardImage
end

function setCardFaceDown(zone, cardImage)
    -- Set the card face-down
    zone.faceUp = false
    -- Return the cardback image
    return "cardback.jpg"
end



function createMonsterActionPanel(zone, zoneIndex, isOpponent)
    isOpponent = isOpponent or false  -- Add this line to set a default value for isOpponent
    local actionPanel = vgui.Create("DFrame")
    actionPanel:SetSize(300, 200)
    actionPanel:SetTitle("Choose Action")
    actionPanel:SetVisible(true)
    actionPanel:SetDraggable(false)
    actionPanel:Center()
    actionPanel:MakePopup()

    -- Add the buttons for each action
    -- Attack
    local attackButton = vgui.Create("DButton", actionPanel)
    attackButton:SetSize(120, 30)
    attackButton:SetPos(20, 50)
    attackButton:SetText("Attack")
    attackButton.DoClick = function()
        -- Add your attack logic here
        actionPanel:Close()
    end

    -- Toggle position
    local togglePositionButton = vgui.Create("DButton", actionPanel)
    togglePositionButton:SetSize(120, 30)
    togglePositionButton:SetPos(160, 50)
    togglePositionButton:SetText("Toggle Position")
    togglePositionButton.DoClick = function()
        -- Add your toggle position logic here
		print(zone:GetImage())
       toggleCardPosition(zone, zoneIndex, isOpponent)
	   actionPanel:Close()
    end

    -- Activate effect
    local activateEffectButton = vgui.Create("DButton", actionPanel)
    activateEffectButton:SetSize(120, 30)
    activateEffectButton:SetPos(20, 100)
    activateEffectButton:SetText("Activate Effect")
    activateEffectButton.DoClick = function()
        -- Add your activate effect logic here
        actionPanel:Close()
    end

    -- Tribute
    local tributeButton = vgui.Create("DButton", actionPanel)
    tributeButton:SetSize(120, 30)
    tributeButton:SetPos(160, 100)
    tributeButton:SetText("Tribute")
    tributeButton.DoClick = function()
        -- Add your tribute logic here
        actionPanel:Close()
    end
end

function toggleCardPosition(zone, zoneIndex, isOpponent)
    local imagePath = zone:GetImage()
    local fileName, fileExtension = string.match(imagePath, "(.+)(%..+)")
    
    if zone.defMode then
        fileName = string.gsub(fileName, "_defense", "")
        zone.defMode = false
    else
        if not string.find(fileName, "_defense") then
            fileName = fileName .. "_defense"
        end
        zone.defMode = true
    end
    
    zone:SetImage(fileName .. fileExtension)
	 
    if not isOpponent then
        net.Start("sendDefModeToOpponent")
		net.WriteUInt(zoneIndex, 32)
        net.WriteString(fileName .. fileExtension) -- Update this line to use the new image path
        net.WriteBool(zone.defMode)  -- Send the defense mode status to the server
        net.SendToServer()
    end
end





-------------------------------------------This section is for receiving instructions from the server in net messages:-------------------------------------------------------------------
net.Receive("sendRandomDeckEntry", function(len)  -- this function is called when the server sends a client a random card from their deck and places it in their hand. (draws one card)
    local imagePath = net.ReadString()   -- gets the card image path from the server
    local uniqueID = net.ReadUInt(32)    -- gets the uniqueID of the card from the player_deck table

    -- Find an empty DImageButton in the Hand zone and update it with the received data and if there is no space, disregards the data
    for _, imageButton in ipairs(Hand) do                  
         if imageButton:GetImage() == "vgui/white" then
            imageButton:SetImage(imagePath)
            imageButton.uniqueID = uniqueID
            break
        end
    end
end)

net.Receive("receiveCardDataFromOpponent", function(len)       -- whenever the opponent player has sent their card data
    local zoneIndex = net.ReadUInt(32)                         -- read these variables sent in the net message
    local imagePath = net.ReadString()
    local uniqueID = net.ReadUInt(32)
	local faceUp = net.ReadBool()
	local zoneType = net.ReadUInt(2)
	
  if zoneType == 1 then                                        -- if zoneType is 1 which means its spell or trap card data then
	local opponentSpellTrap = OpponentSpellsTraps[zoneIndex]   
	if opponentSpellTrap then
        opponentSpellTrap:SetImage(imagePath)                  -- set the opponents field zone data with the cards image
        opponentSpellTrap.uniqueID = uniqueID                  -- and the card's unique id
    end
  else                                                       -- else it will be a monster card so do the same for that in monster zones
    local opponentMonsterZone = OpponentMonsters[zoneIndex]
    if opponentMonsterZone then
        opponentMonsterZone:SetImage(imagePath)
        opponentMonsterZone.uniqueID = uniqueID
		opponentMonsterZone.faceUp = faceUp
    end
  end
end)

net.Receive("receiveDefModeFromOpponent", function(len)
    local zoneIndex = net.ReadUInt(32)
    local imagePath = net.ReadString()
    local defMode = net.ReadBool()

    local opponentMonsterZone = OpponentMonsters[zoneIndex]
    if opponentMonsterZone then
        opponentMonsterZone:SetImage(imagePath)
        opponentMonsterZone.defMode = defMode
    end
end)



local localPlayerIsCurrentPlayer = false      -- creates this variable and sets it to boolean: false.
net.Receive("newTurn", function(len)          -- when this net message is received from the server.
    local newCurrentPlayer = net.ReadEntity() -- reads the entity sent in this message and assigns it to this variable.

    if newCurrentPlayer == LocalPlayer() then  -- if the player entity that was sent in the net message is the same as the client that is running this code right now
        localPlayerIsCurrentPlayer = true      -- make a new variable we can use to check if it is the current player's turn
    else                                       -- otherwise
        localPlayerIsCurrentPlayer = false     -- the opponent player is the one currently running this code
    end
end)

-------------------------------------------This section is for server-to-client check functions to see if client can do things-------------------------------------------------------------------
function requestCanPlaceCard(callback)                  -- function that asks the server if the player can place a monster card
    net.Start("requestCanPlaceCard")
    net.SendToServer()
    net.Receive("receiveCanPlaceCard", function(len)
        local canPlace = net.ReadBool()
        callback(canPlace)
    end)
end

function requestCanPlaceSpellOrTrapCard(cardID, callback)  -- function that asks the server if the player can place a spell or trap card
    net.Start("requestCanPlaceSpellOrTrapCard")
	net.WriteUInt(cardID, 32)
    net.SendToServer()
    net.Receive("receiveCanPlaceSpellOrTrapCard", function(len)
        local canPlaceSpellTrap = net.ReadBool()
        callback(canPlaceSpellTrap)
    end)
end



