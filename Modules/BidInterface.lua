local _, core = ...;
local _G = _G;
local MonDKP = core.MonDKP;
local L = core.L;

local lootTable = {};

	--[[["132744"] = "|cffa335ee|Hitem:12895::::::::60:::::|h[Breastplate of the Chromatic Flight]|h|r",
	["132585"] = "|cffa335ee|Hitem:16862::::::::60:::::|h[Sabatons of Might]|h|r",
	["133066"] = "|cffff8000|Hitem:17182::::::::60:::::|h[Sulfuras, Hand of Ragnaros]|h|r",
	["133173"] = "|cffa335ee|Hitem:16963::::::::60:::::|h[Helm of Wrath]|h|r",
	["135065"] = "|cffa335ee|Hitem:16961::::::::60:::::|h[Pauldrons of Wrath]|h|r",--]]

local width, height, numrows = 370, 18, 13
local Bids_Submitted = {};
local CurrItemForBid, CurrItemIcon;

-- Broadcast should set LootTable_Set when loot is opened. Starting an auction will update through CurrItem_Set
-- When bid received it will be broadcasted and handled with Bids_Set(). If bid broadcasting is off, window will be reduced in size and scrollframe removed.

function MonDKP:LootTable_Set(lootList)
	lootTable = lootList
end

local function SortBidTable()             -- sorts the Loot History Table by date
	mode = MonDKP_DB.modes.mode;
	table.sort(Bids_Submitted, function(a, b)
	    if mode == "Minimum Bid Values" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Minimum Bid") then
	    	return a["bid"] > b["bid"]
	    elseif mode == "Static Item Values" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Static") then
	    	return a["dkp"] > b["dkp"]
	    elseif mode == "Roll Based Bidding" then
	    	return a["roll"] > b["roll"]
	    end
  	end)
end

local function RollMinMax_Get()
	local search = MonDKP:Table_Search(MonDKP_DKPTable, UnitName("player"))
	local minRoll;
	local maxRoll;

	if MonDKP_DB.modes.rolls.UsePerc then
		if MonDKP_DB.modes.rolls.min == 0 or MonDKP_DB.modes.rolls.min == 1 then
			minRoll = 1;
		else
			minRoll = MonDKP_DKPTable[search[1][1]].dkp * (MonDKP_DB.modes.rolls.min / 100);
		end
		maxRoll = MonDKP_DKPTable[search[1][1]].dkp * (MonDKP_DB.modes.rolls.max / 100) + MonDKP_DB.modes.rolls.AddToMax;
	elseif not MonDKP_DB.modes.rolls.UsePerc then
		minRoll = MonDKP_DB.modes.rolls.min;

		if MonDKP_DB.modes.rolls.max == 0 then
			maxRoll = MonDKP_DKPTable[search[1][1]].dkp + MonDKP_DB.modes.rolls.AddToMax;
		else
			maxRoll = MonDKP_DB.modes.rolls.max + MonDKP_DB.modes.rolls.AddToMax;
		end
	end
	if tonumber(minRoll) < 1 then minRoll = 1 end
	if tonumber(maxRoll) < 1 then maxRoll = 1 end

	return minRoll, maxRoll;
end

local function UpdateBidderWindow()
	local i = 1;
	local mode = MonDKP_DB.modes.mode;
	local _,_,_,_,_,_,_,_,_,icon = GetItemInfo(CurrItemForBid)

	for j=2, 10 do
		core.BidInterface.LootTableIcons[j]:Hide()
		core.BidInterface.LootTableButtons[j]:Hide();
	end
	core.BidInterface.lootContainer:SetSize(35, 35)

	for k,v in pairs(lootTable) do
		core.BidInterface.LootTableIcons[i]:SetTexture(tonumber(v.icon))
		core.BidInterface.LootTableIcons[i]:Show()
		core.BidInterface.LootTableButtons[i]:Show();
		core.BidInterface.LootTableButtons[i]:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self:GetParent(), "ANCHOR_BOTTOMRIGHT", 0, 500);
			GameTooltip:SetHyperlink(v.link)
		end)
		core.BidInterface.LootTableButtons[i]:SetScript("OnLeave", function(self)
			GameTooltip:Hide();
		end)
		if tonumber(v.icon) == icon then
			ActionButton_ShowOverlayGlow(core.BidInterface.LootTableButtons[i])
		else
			ActionButton_HideOverlayGlow(core.BidInterface.LootTableButtons[i])
		end
		i = i+1
	end

	if i==1 then
		core.BidInterface.lootContainer:SetSize(35, 35)
	else
		i = i-1
		core.BidInterface.lootContainer:SetSize(43*i, 35)
	end

	if mode == "Minimum Bid Values" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Minimum Bid") then
		core.BidInterface.MinBidHeader:SetText(L["MINIMUMBID"]..":")
		core.BidInterface.SubmitBid:SetPoint("LEFT", core.BidInterface.Bid, "RIGHT", 8, 0)
		core.BidInterface.SubmitBid:SetText(L["SUBMITBID"])
		core.BidInterface.Bid:Show();
		core.BidInterface.CancelBid:Show();
	elseif mode == "Roll Based Bidding" then
		core.BidInterface.MinBidHeader:SetText(L["ITEMCOST"]..":")
		core.BidInterface.SubmitBid:SetPoint("LEFT", core.BidInterface.BidHeader, "RIGHT", 8, 0)
		core.BidInterface.SubmitBid:SetText(L["ROLL"])
		core.BidInterface.Bid:Hide();
		core.BidInterface.CancelBid:Hide();
	else
		core.BidInterface.MinBidHeader:SetText(L["ITEMCOST"]..":")
		core.BidInterface.SubmitBid:SetPoint("LEFT", core.BidInterface.BidHeader, "RIGHT", 8, 0)
		core.BidInterface.SubmitBid:SetText(L["SUBMITBID"])
		core.BidInterface.Bid:Hide();
		core.BidInterface.CancelBid:Show();
	end


	core.BidInterface.item:SetText(CurrItemForBid)
	core.BidInterface.Boss:SetText(MonDKP_DB.bossargs.LastKilledBoss)
end

function BidInterface_Update()
	local numOptions = #Bids_Submitted;
	local index, row
    local offset = FauxScrollFrame_GetOffset(core.BidInterface.bidTable) or 0
    local rank;

    SortBidTable()
    for i=1, numrows do
    	row = core.BidInterface.bidTable.Rows[i]
    	row:Hide()
    end    
	if Bids_Submitted[1] and Bids_Submitted[1].bid and core.BidInterface.bidTable:IsShown() then
		core.BidInterface.Bid:SetNumber(Bids_Submitted[1].bid)
	end
    for i=1, #Bids_Submitted do
        row = core.BidInterface.bidTable.Rows[i]
        index = offset + i
        local dkp_total = MonDKP:Table_Search(MonDKP_DKPTable, Bids_Submitted[i].player)
        local c = MonDKP:GetCColors(MonDKP_DKPTable[dkp_total[1][1]].class)
        rank = MonDKP:GetGuildRank(Bids_Submitted[i].player)
        if Bids_Submitted[index] then
            row:Show()
            row.index = index
            row.Strings[1]:SetText(Bids_Submitted[i].player.." |cff666666("..rank..")|r")
            row.Strings[1]:SetTextColor(c.r, c.g, c.b, 1)
            if mode == "Minimum Bid Values" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Minimum Bid") then
            	row.Strings[2]:SetText(Bids_Submitted[i].bid)
            	row.Strings[3]:SetText(MonDKP_round(MonDKP_DKPTable[dkp_total[1][1]].dkp, MonDKP_DB.modes.rounding))
            elseif mode == "Roll Based Bidding" then
            	local minRoll;
            	local maxRoll;

            	if MonDKP_DB.modes.rolls.UsePerc then
            		if MonDKP_DB.modes.rolls.min == 0 or MonDKP_DB.modes.rolls.min == 1 then
            			minRoll = 1;
            		else
            			minRoll = MonDKP_DKPTable[dkp_total[1][1]].dkp * (MonDKP_DB.modes.rolls.min / 100);
            		end
            		maxRoll = MonDKP_DKPTable[dkp_total[1][1]].dkp * (MonDKP_DB.modes.rolls.max / 100) + MonDKP_DB.modes.rolls.AddToMax;
            	elseif not MonDKP_DB.modes.rolls.UsePerc then
            		minRoll = MonDKP_DB.modes.rolls.min;

            		if MonDKP_DB.modes.rolls.max == 0 then
            			maxRoll = MonDKP_DKPTable[dkp_total[1][1]].dkp + MonDKP_DB.modes.rolls.AddToMax;
            		else
            			maxRoll = MonDKP_DB.modes.rolls.max + MonDKP_DB.modes.rolls.AddToMax;
            		end
            	end
            	if tonumber(minRoll) < 1 then minRoll = 1 end
            	if tonumber(maxRoll) < 1 then maxRoll = 1 end

            	row.Strings[2]:SetText(Bids_Submitted[i].roll..Bids_Submitted[i].range)
            	row.Strings[3]:SetText(math.floor(minRoll).."-"..math.floor(maxRoll))
            elseif mode == "Static Item Values" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Static") then
            	row.Strings[3]:SetText(MonDKP_round(Bids_Submitted[i].dkp, MonDKP_DB.modes.rounding))
            end
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(core.BidInterface.bidTable, numOptions, numrows, height, nil, nil, nil, nil, nil, nil, true) -- alwaysShowScrollBar= true to stop frame from hiding
end

function MonDKP:BidInterface_Toggle()
	core.BidInterface = core.BidInterface or MonDKP:BidInterface_Create()
	if core.BidInterface:IsShown() then core.BidInterface:Hide(); end
	local f = core.BidInterface;
	local mode = MonDKP_DB.modes.mode;

	if MonDKP_DB.modes.BroadcastBids and not core.BiddingWindow then
		core.BidInterface:SetHeight(500);
		core.BidInterface.bidTable:Show();
		for k, v in pairs(f.headerButtons) do
			v:SetHighlightTexture("Interface\\BUTTONS\\BlueGrad64_faded.blp");
			if k == "player" then
				if mode == "Minimum Bid Values" or mode == "Roll Based Bidding" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Minimum Bid") then
					v:SetSize((width/2)-1, height)
					v:Show()
				elseif mode == "Static Item Values" or mode == "Roll Based Bidding" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Static") then
					v:SetSize((width*0.75)-1, height)
					v:Show()
				end
			else
				if mode == "Minimum Bid Values" or mode == "Roll Based Bidding" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Minimum Bid") then
					v:SetSize((width/4)-1, height)
					v:Show();
				elseif mode == "Static Item Values" or mode == "Roll Based Bidding" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Static") then
					if k == "bid" then
						v:Hide()
					else
						v:SetSize((width/4)-1, height)
						v:Show();
					end
				end
				
			end
		end

		if mode == "Minimum Bid Values" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Minimum Bid") then
			f.headerButtons.bid.t:SetText(L["BID"]);
			f.headerButtons.bid.t:Show();
		elseif mode == "Static Item Values" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Static") then
			f.headerButtons.bid.t:Hide(); 
		elseif mode == "Roll Based Bidding" then
			f.headerButtons.bid.t:SetText(L["PLAYERROLL"])
			f.headerButtons.bid.t:Show()
		end

		if mode == "Minimum Bid Values" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Minimum Bid") then
			f.headerButtons.dkp.t:SetText(L["TOTALDKP"]);
			f.headerButtons.dkp.t:Show();
		elseif mode == "Static Item Values" or (mode == "Zero Sum" and MonDKP_DB.modes.ZeroSumBidType == "Static") then
			f.headerButtons.dkp.t:SetText(L["DKP"]);
			f.headerButtons.dkp.t:Show()
		elseif mode == "Roll Based Bidding" then
			f.headerButtons.dkp.t:SetText(L["EXPECTEDROLL"])
			f.headerButtons.dkp.t:Show();
		end

		BidInterface_Update()
	end

	

	core.BidInterface:SetShown(true)
end

local function BidWindowCreateRow(parent, id) -- Create 3 buttons for each row in the list
    local f = CreateFrame("Button", "$parentLine"..id, parent)
    f.Strings = {}
    f:SetSize(width, height)
    f:SetHighlightTexture("Interface\\AddOns\\MonolithDKP\\Media\\Textures\\ListBox-Highlight");
    f:SetNormalTexture("Interface\\COMMON\\talent-blue-glow")
    f:GetNormalTexture():SetAlpha(0.2)
    for i=1, 3 do
        f.Strings[i] = f:CreateFontString(nil, "OVERLAY");
        f.Strings[i]:SetTextColor(1, 1, 1, 1);
        if i==1 then 
        	f.Strings[i]:SetFontObject("MonDKPNormalLeft");
        else
        	f.Strings[i]:SetFontObject("MonDKPNormalCenter");
        end
    end
    f.Strings[1]:SetWidth((width/2)-10)
    f.Strings[2]:SetWidth(width/4)
    f.Strings[3]:SetWidth(width/4)
    f.Strings[1]:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.Strings[2]:SetPoint("LEFT", f.Strings[1], "RIGHT", 0, 0)
    f.Strings[3]:SetPoint("RIGHT", 0, 0)

    return f
end

function MonDKP:CurrItem_Set(item, value, icon, BidHost)
	CurrItemForBid = item;
	CurrItemIcon = icon;

	UpdateBidderWindow()

	if not strfind(value, "%%") and not strfind(value, "DKP") then
		core.BidInterface.MinBid:SetText(value.." DKP");
	else
		core.BidInterface.MinBid:SetText(value);
	end

	if core.BidInterface.Bid:IsShown() then
		core.BidInterface.Bid:SetNumber(value);
	end

	if BidHost and MonDKP_DB.modes.mode ~= "Roll Based Bidding" then
		core.BidInterface.SubmitBid:SetScript("OnClick", function()
			local message;

			if core.BidInterface.Bid:IsShown() then
				message = "!bid "..core.BidInterface.Bid:GetNumber()
			else
				message = "!bid";
			end
			MonDKP.Sync:SendData("MonDKPBidSubmit", tostring(message))
			--SendChatMessage(message, "WHISPER", nil, BidHost)
			core.BidInterface.Bid:ClearFocus();
		end)

		core.BidInterface.CancelBid:SetScript("OnClick", function()
			MonDKP.Sync:SendData("MonDKPBidSubmit", "!bid cancel")
			--SendChatMessage("!bid cancel", "WHISPER", nil, BidHost)
			core.BidInterface.Bid:ClearFocus();
		end)
	elseif MonDKP_DB.modes.mode == "Roll Based Bidding" then
		core.BidInterface.SubmitBid:SetScript("OnClick", function()
			local min, max = RollMinMax_Get()

			RandomRoll(min, max);
		end)
	end

	if not MonDKP_DB.modes.BroadcastBids or core.BidInProgress then
		core.BidInterface:SetHeight(210);
		core.BidInterface.bidTable:Hide();
	else
		core.BidInterface:SetHeight(500);
		core.BidInterface.bidTable:Show();
	end
end

function MonDKP:Bids_Set(entry)
	Bids_Submitted = entry;
	BidInterface_Update();
end

function MonDKP:BidInterface_Create()
	local f = CreateFrame("Frame", "MonDKP_BidderWindow", UIParent, "ShadowOverlaySmallTemplate");

	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 700, -200);
	f:SetSize(400, 500);
	f:SetClampedToScreen(true)
	f:SetBackdrop( {
		bgFile = "Textures\\white.blp", tile = true,                -- White backdrop allows for black background with 1.0 alpha on low alpha containers
		edgeFile = "Interface\\AddOns\\MonolithDKP\\Media\\Textures\\edgefile.tga", tile = true, tileSize = 1, edgeSize = 3,  
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	});
	f:SetBackdropColor(0,0,0,0.9);
	f:SetBackdropBorderColor(1,1,1,1)
	f:SetFrameStrata("DIALOG")
	f:SetFrameLevel(5)
	f:SetMovable(true);
	f:EnableMouse(true);
	f:RegisterForDrag("LeftButton");
	f:SetScript("OnDragStart", f.StartMoving);
	f:SetScript("OnDragStop", f.StopMovingOrSizing);
	f:SetScript("OnHide", function ()
		if core.BiddingInProgress then
			MonDKP:Print(L["CLOSEDBIDINPROGRESS"])
		end
	end)
	f:SetScript("OnMouseDown", function(self)
		self:SetFrameLevel(10)
		if core.ModesWindow then core.ModesWindow:SetFrameLevel(6) end
		if MonDKP.UIConfig then MonDKP.UIConfig:SetFrameLevel(2) end
	end)
	tinsert(UISpecialFrames, f:GetName()); -- Sets frame to close on "Escape"

	  -- Close Button
	f.closeContainer = CreateFrame("Frame", "MonDKPBidderWindowCloseButtonContainer", f)
	f.closeContainer:SetPoint("CENTER", f, "TOPRIGHT", -4, 0)
	f.closeContainer:SetBackdrop({
		bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\MonolithDKP\\Media\\Textures\\edgefile.tga", tile = true, tileSize = 1, edgeSize = 2, 
	});
	f.closeContainer:SetBackdropColor(0,0,0,0.9)
	f.closeContainer:SetBackdropBorderColor(1,1,1,0.2)
	f.closeContainer:SetSize(28, 28)

	f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.closeBtn:SetPoint("CENTER", f.closeContainer, "TOPRIGHT", -14, -14)

	f.LootTableIcons = {}
	f.LootTableButtons = {}

	f.lootContainer = CreateFrame("Frame", "MonDKP_LootContainer", UIParent);
	f.lootContainer:SetPoint("TOP", f, "TOP", 0, -40);
	f.lootContainer:SetSize(35, 35)

	f.Boss = f:CreateFontString(nil, "OVERLAY")
	f.Boss:SetFontObject("MonDKPLargeCenter")
	f.Boss:SetPoint("TOP", f, "TOP", 0, -10)

	for i=1, 10 do
		f.LootTableIcons[i] = f:CreateTexture(nil, "OVERLAY", nil);
		f.LootTableIcons[i]:SetColorTexture(0, 0, 0, 1)
		f.LootTableIcons[i]:SetSize(35, 35);
		f.LootTableIcons[i]:Hide();
		f.LootTableButtons[i] = CreateFrame("Button", "MonDKPBidderLootTableButton", f)
		f.LootTableButtons[i]:SetPoint("TOPLEFT", f.LootTableIcons[i], "TOPLEFT", 0, 0);
		f.LootTableButtons[i]:SetSize(35, 35);
		f.LootTableButtons[i]:Hide()

		if i==1 then
			f.LootTableIcons[i]:SetPoint("LEFT", f.lootContainer, "LEFT", 0, 0);
		else
			f.LootTableIcons[i]:SetPoint("LEFT", f.LootTableIcons[i-1], "RIGHT", 8, 0);
		end
	end

	f.itemHeader = f:CreateFontString(nil, "OVERLAY")
	f.itemHeader:SetFontObject("MonDKPLargeRight");
	f.itemHeader:SetScale(0.7)
	f.itemHeader:SetPoint("TOP", f, "TOP", -160, -135);
	f.itemHeader:SetText(L["ITEM"]..":")

	f.item = f:CreateFontString(nil, "OVERLAY")
	f.item:SetFontObject("MonDKPNormalLeft");
	f.item:SetPoint("LEFT", f.itemHeader, "RIGHT", 5, 2);
	f.item:SetSize(200, 28)

	f.MinBidHeader = f:CreateFontString(nil, "OVERLAY")
	f.MinBidHeader:SetFontObject("MonDKPLargeRight");
	f.MinBidHeader:SetScale(0.7)
	f.MinBidHeader:SetPoint("TOPRIGHT", f.itemHeader, "BOTTOMRIGHT", 0, -15);
	f.MinBidHeader:SetText(L["MINIMUMBID"]..":")

	f.MinBid = f:CreateFontString(nil, "OVERLAY")
	f.MinBid:SetFontObject("MonDKPNormalLeft");
	f.MinBid:SetPoint("LEFT", f.MinBidHeader, "RIGHT", 8, 0);
	f.MinBid:SetSize(200, 28)

    f.BidHeader = f:CreateFontString(nil, "OVERLAY")
	f.BidHeader:SetFontObject("MonDKPLargeRight");
	f.BidHeader:SetScale(0.7)
	f.BidHeader:SetText(L["BID"]..":")
	f.BidHeader:SetPoint("TOPRIGHT", f.MinBidHeader, "BOTTOMRIGHT", 0, -20);

	f.Bid = CreateFrame("EditBox", nil, f)
	f.Bid:SetPoint("LEFT", f.BidHeader, "RIGHT", 8, 0)   
    f.Bid:SetAutoFocus(false)
    f.Bid:SetMultiLine(false)
    f.Bid:SetSize(70, 28)
    f.Bid:SetBackdrop({
  	  bgFile   = "Textures\\white.blp", tile = true,
      edgeFile = "Interface\\AddOns\\MonolithDKP\\Media\\Textures\\edgefile", tile = true, tileSize = 32, edgeSize = 2,
    });
    f.Bid:SetBackdropColor(0,0,0,0.6)
    f.Bid:SetBackdropBorderColor(1,1,1,0.6)
    f.Bid:SetMaxLetters(8)
    f.Bid:SetTextColor(1, 1, 1, 1)
    f.Bid:SetFontObject("MonDKPSmallRight")
    f.Bid:SetTextInsets(10, 10, 5, 5)
    f.Bid:SetScript("OnEscapePressed", function(self)    -- clears focus on esc
      self:ClearFocus()
    end)

    f.BidPlusOne = CreateFrame("Button", nil, f.Bid, "MonolithDKPButtonTemplate")
	f.BidPlusOne:SetPoint("TOPLEFT", f.Bid, "BOTTOMLEFT", 0, -2);
	f.BidPlusOne:SetSize(33,20)
	f.BidPlusOne:SetText("+1");
	f.BidPlusOne:GetFontString():SetTextColor(1, 1, 1, 1)
	f.BidPlusOne:SetNormalFontObject("MonDKPSmallCenter");
	f.BidPlusOne:SetHighlightFontObject("MonDKPSmallCenter");
	f.BidPlusOne:SetScript("OnClick", function()
		f.Bid:SetNumber(f.Bid:GetNumber() + 1);
	end)

	f.BidPlusFive = CreateFrame("Button", nil, f.Bid, "MonolithDKPButtonTemplate")
	f.BidPlusFive:SetPoint("TOPRIGHT", f.Bid, "BOTTOMRIGHT", 0, -2);
	f.BidPlusFive:SetSize(33,20)
	f.BidPlusFive:SetText("+5");
	f.BidPlusFive:GetFontString():SetTextColor(1, 1, 1, 1)
	f.BidPlusFive:SetNormalFontObject("MonDKPSmallCenter");
	f.BidPlusFive:SetHighlightFontObject("MonDKPSmallCenter");
	f.BidPlusFive:SetScript("OnClick", function()
		f.Bid:SetNumber(f.Bid:GetNumber() + 5);
	end)

    f.SubmitBid = CreateFrame("Button", nil, f, "MonolithDKPButtonTemplate")
	f.SubmitBid:SetPoint("LEFT", f.Bid, "RIGHT", 8, 0);
	f.SubmitBid:SetSize(90,25)
	f.SubmitBid:SetText(L["SUBMITBID"]);
	f.SubmitBid:GetFontString():SetTextColor(1, 1, 1, 1)
	f.SubmitBid:SetNormalFontObject("MonDKPSmallCenter");
	f.SubmitBid:SetHighlightFontObject("MonDKPSmallCenter");

	f.CancelBid = CreateFrame("Button", nil, f, "MonolithDKPButtonTemplate")
	f.CancelBid:SetPoint("LEFT", f.SubmitBid, "RIGHT", 8, 0);
	f.CancelBid:SetSize(90,25)
	f.CancelBid:SetText(L["CANCELBID"]);
	f.CancelBid:GetFontString():SetTextColor(1, 1, 1, 1)
	f.CancelBid:SetNormalFontObject("MonDKPSmallCenter");
	f.CancelBid:SetHighlightFontObject("MonDKPSmallCenter");
	f.CancelBid:SetScript("OnClick", function()
		--CancelBid()
		f.Bid:ClearFocus();
	end)

	--------------------------------------------------
	-- Bid Table
	--------------------------------------------------
    f.bidTable = CreateFrame("ScrollFrame", "MonDKP_BiderWindowTable", f, "FauxScrollFrameTemplate")
    f.bidTable:SetSize(width, height*numrows+3)
	f.bidTable:SetBackdrop({
		bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\MonolithDKP\\Media\\Textures\\edgefile.tga", tile = true, tileSize = 1, edgeSize = 2, 
	});
	f.bidTable:SetBackdropColor(0,0,0,0.2)
	f.bidTable:SetBackdropBorderColor(1,1,1,0.4)
    f.bidTable.ScrollBar = FauxScrollFrame_GetChildFrames(f.bidTable)
    f.bidTable.ScrollBar:Hide()
    f.bidTable.Rows = {}
    for i=1, numrows do
        f.bidTable.Rows[i] = BidWindowCreateRow(f.bidTable, i)
        if i==1 then
        	f.bidTable.Rows[i]:SetPoint("TOPLEFT", f.bidTable, "TOPLEFT", 0, -3)
        else	
        	f.bidTable.Rows[i]:SetPoint("TOPLEFT", f.bidTable.Rows[i-1], "BOTTOMLEFT")
        end
    end
    f.bidTable:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, height, BidderScrollFrame_Update)
    end)

	---------------------------------------
	-- Header Buttons
	--------------------------------------- 
	f.headerButtons = {}
	mode = MonDKP_DB.modes.mode;

	f.BidTable_Headers = CreateFrame("Frame", "MonDKPBidderTableHeaders", f.bidTable)
	f.BidTable_Headers:SetSize(370, 22)
	f.BidTable_Headers:SetPoint("BOTTOMLEFT", f.bidTable, "TOPLEFT", 0, 1)
	f.BidTable_Headers:SetBackdrop({
		bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\MonolithDKP\\Media\\Textures\\edgefile.tga", tile = true, tileSize = 1, edgeSize = 2, 
	});
	f.BidTable_Headers:SetBackdropColor(0,0,0,0.8);
	f.BidTable_Headers:SetBackdropBorderColor(1,1,1,0.5)
	f.bidTable:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
	f.BidTable_Headers:Show()

	f.headerButtons.player = CreateFrame("Button", "$ParentButtonPlayer", f.BidTable_Headers)
	f.headerButtons.bid = CreateFrame("Button", "$ParentButtonBid", f.BidTable_Headers)
	f.headerButtons.dkp = CreateFrame("Button", "$ParentSuttonDkp", f.BidTable_Headers)

	f.headerButtons.player:SetPoint("LEFT", f.BidTable_Headers, "LEFT", 2, 0)
	f.headerButtons.bid:SetPoint("LEFT", f.headerButtons.player, "RIGHT", 0, 0)
	f.headerButtons.dkp:SetPoint("RIGHT", f.BidTable_Headers, "RIGHT", -1, 0)

	f.headerButtons.player.t = f.headerButtons.player:CreateFontString(nil, "OVERLAY")
	f.headerButtons.player.t:SetFontObject("MonDKPNormalLeft")
	f.headerButtons.player.t:SetTextColor(1, 1, 1, 1);
	f.headerButtons.player.t:SetPoint("LEFT", f.headerButtons.player, "LEFT", 20, 0);
	f.headerButtons.player.t:SetText(L["PLAYER"]); 

	f.headerButtons.bid.t = f.headerButtons.bid:CreateFontString(nil, "OVERLAY")
	f.headerButtons.bid.t:SetFontObject("MonDKPNormal");
	f.headerButtons.bid.t:SetTextColor(1, 1, 1, 1);
	f.headerButtons.bid.t:SetPoint("CENTER", f.headerButtons.bid, "CENTER", 0, 0);

	f.headerButtons.dkp.t = f.headerButtons.dkp:CreateFontString(nil, "OVERLAY")
	f.headerButtons.dkp.t:SetFontObject("MonDKPNormal")
	f.headerButtons.dkp.t:SetTextColor(1, 1, 1, 1);
	f.headerButtons.dkp.t:SetPoint("CENTER", f.headerButtons.dkp, "CENTER", 0, 0);

	if not MonDKP_DB.modes.BroadcastBids then
		f.bidTable:Hide();
		f:SetHeight(210);
	end; 		--hides table if broadcasting is set to false.

	f:Hide();

	return f;
end