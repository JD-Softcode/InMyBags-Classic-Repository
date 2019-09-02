SLASH_JADBAGSCAN1  = "/imbscan"		--collect all inventory data; xxxcan only be called when at the bankxxx
									--	  NEW in 1.4: can be called away from bank to update personal bags
SLASH_JADBAGRESET1 = "/imbreset"	--purge all inventory data for all characters; there is no undo  ;)
									--    NEW in 1.3: type it twice to confirm
SLASH_JADBAGLIST1  = "/imb"			--show the In My Bags window; optionally follow with a name to see only that inventory
									--    or with letters not a name for a search
									--    NEW in 1.3: shift-click an inventory item to search for it


--You can change these names but will need to reset/rebuild the database for all characters when you do
MAIN_BANK_BAG_NAME  = "Main bank"
OTHER_BANK_BAG_NAME = "Bank bag"
BACKPACK_BAG_NAME   = "Backpack"
ON_PERSON_BAG_NAME  = "On-person bag"


JADBagInventory = {}			-- saved variable, hold all the inventory data
JADBagDisplay = {}				-- built each time the window is displayed
JADBankWindowOpen = 0			-- toggles whenever the bank window is opened or closed
JADBagConfirmReset = 0			-- toggles to ensure reset is entered twice
JADMatchString = ""				-- the search string, if <> ""
_NoErr = 0						-- named constant

SlashCmdList["JADBAGSCAN"] = function(msg, theEditFrame)			-- /imbscan
	local bag, slot, result, bagslots, bagstart, bagstop

	InMyBags:Hide();

		--BANK_CONTAINER Main storage area in the bank (-1)
		--BACKPACK_CONTAINER: Backpack (0)
		--1 through NUM_BAG_SLOTS: Bag slots (as presented in the default UI, numbered right to left)
		--NUM_BAG_SLOTS + 1 through NUM_BAG_SLOTS + NUM_BANKBAGSLOTS: Bank bag slots (as presented in the default UI, numbered left to right)

	if (JADBankWindowOpen > 0)  then
		bagslots = NUM_BAG_SLOTS + NUM_BANKBAGSLOTS + 2
		bagstart = -1		
		bagstop = NUM_BAG_SLOTS + NUM_BANKBAGSLOTS
		result = purgeCharacterEntries("all")
	else		-- bank window is not open
		bagslots = NUM_BAG_SLOTS + 1
		bagstart = 0
		bagstop = NUM_BAG_SLOTS		
		result = purgeCharacterEntries("nobank")
	end
	
	if (result == _NoErr) then

		ChatFrame1:AddMessage( "In My Bags cataloging items from "..bagslots.." containers." )
		for bag = bagstart, bagstop do
	--	ChatFrame1:AddMessage( "Bag "..bag.." has "..GetContainerNumSlots(bag).." slots")
			for slot = 1, GetContainerNumSlots(bag) do
				local texture, count, locked, qualityBroken, readable, lootable, link = GetContainerItemInfo(bag, slot)
				if texture then
					local name, link, quality = GetItemInfo(link)
	--				name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo("itemLink")
	--													   ^^ as in AH ^^
					table.insert(JADBagInventory, {
						["name"]		= name,
						["holder"]		= UnitName("player"),
						["quantity"]	= count,
						["detailLink"]	= link,
						["heldIn"]		= translateBagID(bag)
						}
						)
				end
			end
		end
	
		--ChatFrame1:AddMessage( "JADBagInventory is now "..#JADBagInventory)
		consolidateLikeItems(UnitName("player"))
		ChatFrame1:AddMessage( "In My Bags database updated. Now tracking "..#JADBagInventory.." items.")
	else
		ChatFrame1:AddMessage( "An error occured trying to reset "..UnitName("player").."'s inventory" )
	end
		
	JADBagConfirmReset = 0					--reset delete confirmation flag on any other command
end

SlashCmdList["JADBAGRESET"] = function(msg, theEditFrame)		--  /imbreset
	if ( JADBagConfirmReset > 0 ) then
		JADBagInventory = {}
		ChatFrame1:AddMessage( "In My Bags inventory database reset for all characters.")
		JADBagConfirmReset = 0
	else
		ChatFrame1:AddMessage( "ARE YOU SURE?  Type "..SLASH_JADBAGRESET1.." again to confirm.",255,0,0 )
		JADBagConfirmReset = 1
	end
end

SlashCmdList["JADBAGLIST"] = function(msg, theEditFrame)		--  /imb,  /imb me,  /imb Name,  /imb xxx
	local showNameList = 0
	JADMatchString = ""
	
	if (msg == "") then
		msg = nil
	elseif (msg == "me") then
		msg = UnitName("player")
		showNameList = 1
	else
		local inventorySize = #JADBagInventory
		if (inventorySize > 0 ) then
			for i = 1,inventorySize do
				if ( JADBagInventory[i].holder == msg ) then	-- did user type a stored player name?
					showNameList = 1
					i = inventorySize							-- break out of the loop
				end
			end
		end
	end
	
	if (showNameList == 1) then
		showTheList(msg)
	else
		if ( msg and string.find(msg, "Hitem") ) then			-- is not nil & a link?
			local linkExtractStart = string.find(msg, "|h%[") + 3
			local linkExtractStop  = string.find(msg, "%]|h") - 1
			msg = string.sub(msg, linkExtractStart,  linkExtractStop)
		end
		
		JADMatchString = ( msg or "" )    -- the message, unless it's nil then make it ""
		showTheList()
	end
	JADBagConfirmReset = 0				  --reset delete confirmation flag on any other command
end

function InMyBags_OnLoad(frame)
--	frame:RegisterEvent("ADDON_LOADED")	-- ready to process saved data
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")	-- everything ready
	frame:RegisterEvent("BANKFRAME_OPENED")	-- when the bank is opened
	frame:RegisterEvent("BANKFRAME_CLOSED")	-- when the bank is closed
--	frame:RegisterEvent("BAG_OPEN")	-- when a bag is opened // no longer being sent in 4.3
--	frame:RegisterEvent("BAG_UPDATE")	-- when contents of a bag change; FUTURE OPPORTUNITY
	frame:RegisterForDrag("LeftButton")
end

function InMyBags_OnEvent(frame, event, arg1, ...)

	if event == "PLAYER_ENTERING_WORLD" then			-- set stuff up
		InMyBagsTitleText:SetText("In My Bags")
		InMyBagsPortrait:SetTexture("Interface\\MERCHANTFRAME\\UI-BuyBack-Icon")
		JADBankWindowOpen = 0							-- bank is always closed on /reload
		table.insert(UISpecialFrames, "InMyBags")		--makes it close with ESC key (silently)
	end		

	if event == "BANKFRAME_OPENED" then
		JADBankWindowOpen = 1
	end		

	if event == "BANKFRAME_CLOSED" then
		JADBankWindowOpen = 0
	end		
end


function translateBagID (bag)
	local itemSource
	if (bag == -1) then
		itemSource = MAIN_BANK_BAG_NAME
	elseif (bag == 0) then
		itemSource = BACKPACK_BAG_NAME
	elseif (bag <= NUM_BAG_SLOTS) then
		itemSource = ON_PERSON_BAG_NAME
	else 
		itemSource = OTHER_BANK_BAG_NAME
	end
	return itemSource
end

function purgeCharacterEntries(purgeType)
	local total = #JADBagInventory
	if (total > 0) then 
		for i = #JADBagInventory, 1, -1 do		--count backwards else the list shrinks while it's counting up
			if (JADBagInventory[i].holder == UnitName("player")) then
				if (purgeType == "all") then
					table.remove(JADBagInventory, i)					-- no idea how to trap an error with this call
				else		-- "nobank"
					if 	(JADBagInventory[i].heldIn == BACKPACK_BAG_NAME or JADBagInventory[i].heldIn == ON_PERSON_BAG_NAME) then
						table.remove(JADBagInventory, i)
					end
				end
			end
		end
	end
	return _NoErr
end

function buildListForDisplay(limitTo)
	JADBagDisplay = {}		--start over; reset table
	--local countAdded = 0
	--local countAppended = 0
	local totalVendorValue = 0
	local money = 0
	
	for i = 1 , #JADBagInventory do
		if ( (limitTo==nil) or ( JADBagInventory[i].holder == limitTo) ) then
		
			if ( (JADMatchString == "") or string.find(string.lower(JADBagInventory[i].name),string.lower(JADMatchString)) ) then
		
				displayListFoundLine = itemAlreadyInDisplayList(JADBagInventory[i].name)
				
				if ( displayListFoundLine > 0 ) then
					appendPlayerInventory(	displayListFoundLine,
											JADBagInventory[i].holder,
											JADBagInventory[i].quantity,
											JADBagInventory[i].heldIn
											);
					--countAppended = countAppended + 1
				else
					addPlayerInventory(		JADBagInventory[i].name,
											JADBagInventory[i].holder,
											JADBagInventory[i].quantity,
											JADBagInventory[i].detailLink,
											JADBagInventory[i].heldIn
											);
					--countAdded = countAdded + 1
				end
			
			end
			
			money = select(11, GetItemInfo(JADBagInventory[i].detailLink))		--can sometimes return nil, so...
			if (money) then
				totalVendorValue = totalVendorValue + money
			end			
		end
	end
	table.sort(JADBagDisplay,nameSort)
	
	if (JADMatchString == "") then
		InMyBagsVendor:SetText("Total vendor value:|n"..GetCoinTextureString(totalVendorValue))
	else
		InMyBagsVendor:SetText("Limiting list to:|n\""..JADMatchString.."\"")
	end	
	
--	ChatFrame1:AddMessage( "build for display created "..countAdded.." lines which contained "..countAppended.." combined records." )
	return _NoErr
end
	
function nameSort(item1, item2)
	if (item1.itemName < item2.itemName) then
		return true
	else
		return false
	end
end

function addPlayerInventory(theName, theHolder, theQuantity, theLink, theBag)
	--local bagIcon = "|TInterface\\ICONS\\INV_Misc_Bag_08:16:16:0:1|t"

	if (theHolder == UnitName("player")) then
		theHolder = "|cffffffdd" .. theHolder		--hilight in color the current player's name and inventory
	end

	local theTexture = select(10, GetItemInfo(theLink))			--can return nil, so...
	if theTexture == nil then 
		theTexture = "|TInterface\\ICONS\\WoWUnknownItem01:0|t"
	end

	table.insert(JADBagDisplay, {
		["itemName"]	= theName,
		["icon"]		= theTexture,
		["hyperlink"]	= theLink,
		["holders"]		= theHolder .. ": " .. theQuantity .. " in " .. graphicBag(theBag) .."|r",
				-- the |r reset is here in case of the color shift from a few lines above, otherwise ignored
		["totalCount"]	= theQuantity
		}
		)
end

function appendPlayerInventory(lineNum, theHolder, theQuantity, theBag)
	if (theHolder == UnitName("player")) then
		theHolder = "|cffffffdd" .. theHolder 
	end
	JADBagDisplay[lineNum].holders = JADBagDisplay[lineNum].holders .. ", " .. theHolder .. ": " .. theQuantity .. " in " .. graphicBag(theBag) .."|r"
	JADBagDisplay[lineNum].totalCount = JADBagDisplay[lineNum].totalCount + theQuantity
end

function graphicBag(theBag)
	local bagTexture
	if (theBag == MAIN_BANK_BAG_NAME) then
		bagTexture = "ACHIEVEMENT_GUILDPERK_MOBILEBANKING"
	elseif (theBag == OTHER_BANK_BAG_NAME) then
		bagTexture = "INV_Misc_Bag_10_Red"
	elseif (theBag == BACKPACK_BAG_NAME) then
		bagTexture = "INV_Misc_Bag_08"
	else
		bagTexture = "INV_Misc_Bag_09_Blue"
	end
	return "|TInterface\\ICONS\\"..bagTexture..":17:17:0:0|t"..theBag
end


function itemAlreadyInDisplayList(theNameSeeking)
	local foundAt = 0
	local displaySize = #JADBagDisplay
	if (displaySize > 0 ) then
		for i = 1,displaySize do
			if ( JADBagDisplay[i].itemName == theNameSeeking ) then
				foundAt = i
				i = displaySize
			end
		end
	end
	return foundAt
end

function consolidateLikeItems(playerName)
	local startSize = #JADBagInventory
	--local playerCheckCount=0
	--local purged = 0
	
	local compareline = 1
	
	repeat
		if ( JADBagInventory[compareline].holder == playerName) then
			--playerCheckCount = playerCheckCount + 1
			for i = #JADBagInventory, compareline+1, -1 do
				if ( JADBagInventory[i].name == JADBagInventory[compareline].name ) then
					if ( JADBagInventory[i].heldIn == JADBagInventory[compareline].heldIn ) then			
						JADBagInventory[compareline].quantity = JADBagInventory[compareline].quantity + JADBagInventory[i].quantity
						table.remove(JADBagInventory, i)
						--purged = purged + 1
					end
				end
			end
		end
		compareline = compareline + 1	
	until (compareline >= #JADBagInventory)
	--ChatFrame1:AddMessage( "Reduced "..playerCheckCount.." of "..playerName.." records by "..purged.." entires." )
	--ChatFrame1:AddMessage( "   JADBagInventory from "..startSize.." to "..#JADBagInventory )
	return _NoErr
end

--**********************************************************
function showTheList(playerName)
	buildListForDisplay(playerName);				--create the JADBagDisplay table
	InMyBags:Show();
	
	InMyBagsScrollFrameScrollBar:SetValue(1);
	if (#JADBagDisplay > 8) then
		InMyBagsScrollFrameScrollBar:SetMinMaxValues(1,#JADBagDisplay-8)
		InMyBagsScrollFrameScrollBar.scrollStep = 8;		--how much to move when clicking the up/down buttons, or mouse wheel
	else
		InMyBagsScrollFrameScrollBar:SetMinMaxValues(1,1)
		InMyBagsScrollFrameScrollBar.scrollStep = 1;
		
	end

	paintTheLines(1)
end

function paintTheLines(startLine)
	if ( startLine+8 > #JADBagDisplay) then			-- last list item never above the bottom...
		startLine = #JADBagDisplay - 8
	end
	startLine = startLine - 1
	if ( startLine < 0 ) then						-- unless it's a really short list!
		startLine = 0
	end
	
	local showName
	local quality
	local qualityColor

	for i = 1, 9 do
		if ( i+startLine <= #JADBagDisplay ) then											--in case a really short list
			showName, _, quality = GetItemInfo(JADBagDisplay[i+startLine].hyperlink);		--can return nil, so...
			if ( (showName == nil) or (quality == nil) ) then
				showName = "Unknown"
				quality = 0
			end
			qualityColor = select(4, GetItemQualityColor(quality))
			_G["InMyBagsLine0"..i.."LineIconNormalTexture" ]:SetTexture(JADBagDisplay[i+startLine].icon);
			_G["InMyBagsLine0"..i.."LineIconLineTotalCount"]:SetText(JADBagDisplay[i+startLine].totalCount);		
			_G["InMyBagsLine0"..i.."LineNameText"          ]:SetText("|c"..qualityColor..showName.."|r");
			_G["InMyBagsLine0"..i.."LineHyperlink"         ]:SetText(JADBagDisplay[i+startLine].hyperlink);  --hidden; for tooltip
			_G["InMyBagsLine0"..i.."LineHolderString"      ]:SetText(JADBagDisplay[i+startLine].holders);
		else
			_G["InMyBagsLine0"..i.."LineIconNormalTexture" ]:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag");
			_G["InMyBagsLine0"..i.."LineIconLineTotalCount"]:SetText("");		
			_G["InMyBagsLine0"..i.."LineNameText"          ]:SetText("");
			_G["InMyBagsLine0"..i.."LineHyperlink"         ]:SetText(nil);  --hidden; for tooltip
			_G["InMyBagsLine0"..i.."LineHolderString"      ]:SetText("");		
		end
	end	
end

function InMyBagsItem_OnMouseEnter(self)
	local original = self:GetName()
	-- turn InMyBagsLine0xLineIcon  into  InMyBagsLine0xLineHyperlink
	local converted = string.gsub(original, "Icon", "Hyperlink")
	if ( _G[converted]:GetText() ) then 	--not nil
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(_G[converted]:GetText())
		GameTooltip:Show()
	else
		GameTooltip:Hide()
	end
end

function InMyBagsFrameBrowse_Update()		--can be called anytime, but always when scroll bar clicked/scrolled

	local totalItems = #JADBagDisplay;
	local scrollPosit = InMyBagsScrollFrameScrollBar:GetValue();
	local minScroll
	local maxScroll
	minScroll, maxScroll = InMyBagsScrollFrameScrollBar:GetMinMaxValues();

	if (scrollPosit > minScroll) then
		InMyBagsScrollFrameScrollBarScrollUpButton:Enable();
	else
		InMyBagsScrollFrameScrollBarScrollUpButton:Disable();
	end
	
	if (scrollPosit < maxScroll) then
		InMyBagsScrollFrameScrollBarScrollDownButton:Enable();
	else
		InMyBagsScrollFrameScrollBarScrollDownButton:Disable();
	end

	paintTheLines(math.floor(scrollPosit))
	
	local checkUnderMouse = GetMouseFocus():GetName();
	if ( string.sub(checkUnderMouse,-8) == "LineIcon" ) then			--RIGHT$
		InMyBagsItem_OnMouseEnter(GetMouseFocus())						--update the tooltip
	end

--	ChatFrame1:AddMessage( "In the LUA update function with scroller at " .. minScroll.."-->"..scrollPosit.."-->"..maxScroll )
end

