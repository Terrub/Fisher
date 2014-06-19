----------------------------------------------------------------
-- "UP VALUES" FOR SPEED ---------------------------------------
----------------------------------------------------------------

local mathMin = math.min;
local mathMax = math.max;
local stringFind = string.find;
local tostring = tostring;
local type = type;
local error = error;
local pairs = pairs;

----------------------------------------------------------------
-- CONSTANTS THAT SHOULD BE GLOBAL PROBABLY --------------------
----------------------------------------------------------------

local SCRIPTHANDLER_ON_EVENT = "OnEvent";
local SCRIPTHANDLER_ON_DRAG_START = "OnDragStart";
local SCRIPTHANDLER_ON_DRAG_STOP = "OnDragStop";

----------------------------------------------------------------
-- HELPER FUNCTIONS --------------------------------------------
----------------------------------------------------------------

--	These should be moved into the core at one point.

local merge = function(left, right)
	
	local t = {};
	
	if type(left) ~= "table" or type(right) ~= "table" then
	
		error("Usage: merge(left <table>, right <table>)");
		
	end

	-- copy left into temp table.
	for k, v in pairs(left) do
	
		t[k] = v;
	
	end
	
	-- Add or overwrite right values.
	for k, v in pairs(right) do
		
		t[k] = v;
	
	end
	
	return t;
	
end

--------

local toColourisedString = function(value)

	local val;

	if type(value) == "string" then

		val = "|cffffffff" .. value .. "|r";
	
	elseif type(value) == "number" then
	
		val = "|cffffff33" .. tostring(value) .. "|r";
	
	elseif type(value) == "boolean" then
	
		val = "|cff9999ff" .. tostring(value) .. "|r";
	
	end
	
	return val;
	
end

--------

local prt = function(message)

	if (message and message ~= "") then
	
		if type(message) ~= "string" then
			
			message = tostring(message);
			
		end
		
		DEFAULT_CHAT_FRAME:AddMessage(message);
	
	end

end;

----------------------------------------------------------------
-- FISHER ADDON ------------------------------------------------
----------------------------------------------------------------

Fisher = CreateFrame("FRAME", "Fisher", UIParent);

local this = Fisher;

-- Add slashcommand match entries into the global namespace for the client to pick up.
SLASH_FISHER1 = "/fisher";

----------------------------------------------------------------
-- DATABASE KEYS -----------------------------------------------
----------------------------------------------------------------

-- IF ANY OF THE >>VALUES<< CHANGE YOU WILL RESET THE STORED
-- VARIABLES OF THE PLAYER. EFFECTIVELY DELETING THEIR CUSTOM-
-- ISATION SETTINGS!!!
--
-- Changing the constant itself may cause errors in some cases.
-- Or outright kill the addon alltogether.

local IS_ADDON_ACTIVATED = "is_addon_activated";
local IS_ADDON_LOCKED = "is_addon_locked";
local POSITION_POINT = "position_point";
local POSITION_X = "position_x";
local POSITION_Y = "position_y";
local DB_VERSION = "db_version";
local BAR_WIDTH = "bar_width";
local BAR_HEIGHT = "bar_height";
local MH_ENCHANT_CURRENT_CHARGES = "mh_enchant_current_charges";
local OH_ENCHANT_CURRENT_CHARGES = "oh_enchant_current_charges";
local MH_ENCHANT_CURRENT_EXPIRATION = "mh_enchant_current_expiration";
local OH_ENCHANT_CURRENT_EXPIRATION = "oh_enchant_current_expiration";

local _default_db = {
	[IS_ADDON_ACTIVATED] = false;
	[IS_ADDON_LOCKED] = true;
	[POSITION_POINT] = "CENTER";
	[POSITION_X] = 0;
	[POSITION_Y] = -150;
	[BAR_WIDTH] = 150;
	[BAR_HEIGHT] = 5;
	[MH_ENCHANT_CURRENT_CHARGES] = 0;
	[OH_ENCHANT_CURRENT_CHARGES] = 0;
	[MH_ENCHANT_CURRENT_EXPIRATION] = 0;
	[OH_ENCHANT_CURRENT_EXPIRATION] = 0;
	[DB_VERSION] = 2;
};

----------------------------------------------------------------
-- PRIVATE VARIABLES -------------------------------------------
----------------------------------------------------------------

local _initialisation_event = "ADDON_LOADED";

local _unit_name;
local _realm_name;
local _profile_id;
local _db;

-- Main hand enchant
local _mh_progress_bar;
local _mh_ench_expiration = 0;
local _mh_ench_charges = 0;

-- Off hand enchant
local _oh_progress_bar;
local _oh_ench_expiration = 0;
local _oh_ench_charges = 0;

local _event_handlers;
local _command_list;

----------------------------------------------------------------
-- PRIVATE FUNCTIONS -------------------------------------------
----------------------------------------------------------------

local _report = function(label, message)

	label = tostring(label);
	message = tostring(message);

	local str = "|cff22ff22Fisher|r - |cff999999" .. label .. ":|r " .. message;

	DEFAULT_CHAT_FRAME:AddMessage(str);

end

--------

local _addEvent = function(event_name, eventHandler)

	if 	(not event_name)
	or 	(event_name == "")
	or 	(not eventHandler)
	or 	(type(eventHandler) ~= "function") then
	
		error("Usage: _addEvent(event_name <string>, eventHandler <function>)");
	
	end
	
	_event_handlers[event_name] = eventHandler;
	
	this:RegisterEvent(event_name);

end

--------

local _removeEvent = function(event_name)

	local eventHandler = _event_handlers[event_name];
	
	if not eventHandler then
	
		error("No known eventhandler found for event: " .. tostring(event_name));
		
	end
	
	-- GC should pick this up when a new assignment happens
	_event_handlers[event_name] = nil;
	
	this:UnregisterEvent(event_name);

end

--------

local _resetMainHandWeapon = function()

	_mh_progress_bar:SetWidth(_db[BAR_WIDTH]);
	_mh_progress_bar:SetBackdropColor(0.5, 0, 0, 1); -- Turn red to indicate empty
	_mh_ench_expiration = 0;

end

--------

local _resetOffHandWeapon = function()

	_oh_progress_bar:SetWidth(_db[BAR_WIDTH]);
	_oh_progress_bar:SetBackdropColor(0.5, 0, 0, 1); -- Turn red to indicate empty
	_oh_ench_expiration = 0;
	
end

--------

local _setMainHandWeaponEnchant = function(cur_charges, max_charges)

	if max_charges then
		-- prt("New MH enchant?");
		if type(max_charges) ~= "number" then
		
			error("Usage: _setMainHandWeaponEnchant(cur_charges <number>, max_charges <number>)");
		
		end
	
		_mh_ench_max_charges = mathMax(max_charges, 0);
		_mh_progress_bar:SetBackdropColor(0, 0.5, 0, 1);
	
	end
	
	-- prt("MH normal update");
	_mh_ench_charges = cur_charges;
	
	_mh_progress_bar:SetWidth(_db[BAR_WIDTH] * mathMin((cur_charges / _mh_ench_max_charges), 1));

end

--------

local _setOffHandWeaponEnchant = function(cur_charges, max_charges)

	if max_charges then
		-- prt("New OH enchant?");
		if type(max_charges) ~= "number" then
		
			error("Usage: _setOffHandWeaponEnchant(cur_charges <number>, max_charges <number>)");
		
		end
	
		_oh_ench_max_charges = mathMax(max_charges, 0);
		_oh_progress_bar:SetBackdropColor(0, 0.5, 0, 1);
	
	end
	
	_oh_ench_charges = cur_charges;
	
	_oh_progress_bar:SetWidth(_db[BAR_WIDTH] * mathMin((cur_charges / _oh_ench_max_charges), 1));

end

--------

local _validateMainHandEnchant = function(mh_ench, mh_expiration, mh_charges)

	if not mh_ench then
		-- prt("Used to have a mh enchant we now lost.");
		_resetMainHandWeapon();
		return;
	
	end
	
	if mh_expiration then
	
		if mh_expiration > _mh_ench_expiration then
			-- prt("New enchant probably. Need to update max charges and what not.");
			_setMainHandWeaponEnchant(mh_charges, mh_charges);
		
		else
		
			_setMainHandWeaponEnchant(mh_charges);
			
		end
		
		_mh_ench_expiration = mh_expiration;
	
	end
	
end

--------

local _validateOffHandEnchant = function(oh_ench, oh_expiration, oh_charges)

	if not oh_ench then
		-- prt("Used to have an offhand enchant we now lost.");
		_resetOffHandWeapon();
		return;
	
	end

	if oh_expiration then

		
		if oh_expiration > _oh_ench_expiration then
			-- prt("New offhand enchant. Need to update max charges and what not.");
			_setOffHandWeaponEnchant(oh_charges, oh_charges);

		else

			_setOffHandWeaponEnchant(oh_charges);
			
		end

		_oh_ench_expiration = oh_expiration;
	
	end
	
end

--------

local _validateWeaponEnchants = function()

	-- prt("Getting weapon enchant info");
	local 	mh_ench,
			mh_expiration,
			mh_charges,
			oh_ench,
			oh_expiration,
			oh_charges = GetWeaponEnchantInfo();
	
	_validateMainHandEnchant(mh_ench, mh_expiration, mh_charges);
	_validateOffHandEnchant(oh_ench, oh_expiration, oh_charges);
		
end

--------

local _eventCoordinator = function()

	-- given:
	-- event <string> The event name that triggered.
	-- arg1, arg2, ..., arg9 <*> Given arguments specific to the event.
	
	local eventHandler = _event_handlers[event];
	
	if not eventHandler then
	
		error("No known eventhandler found for event: " .. tostring(event));
		
	end
	
	eventHandler(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9);
	
end

--------

local _printSlashCommandList = function()

	_report("Listing", "Slash commands");

	local str;
	local description;
	local current_value;
	
	for name, cmd_object in pairs(_command_list) do
		
		description = cmd_object.description;
		
		if (not description) then
		
			error('Attempt to print slash command with name:"' .. name .. '" without valid description');
			
		end
	
		str = SLASH_FISHER1 .. " " .. name .. " " .. description;
		
		-- If the slash command sets a value we should have 
		if (cmd_object.value) then
		
			str = str .. " (|cff666666Currently:|r " .. toColourisedString(_db[cmd_object.value]) .. ")";
		
		end
		
		prt(str);
	
	end
		
end

--------

local _startMoving = function()

	this:StartMoving();

end

--------

local _stopMovingOrSizing = function()

	this:StopMovingOrSizing();
	
	_db[POSITION_POINT], _, _, _db[POSITION_X], _db[POSITION_Y] = this:GetPoint();

end

--------

local _unlockAddon = function()

	-- Make the left mouse button trigger drag events
	this:RegisterForDrag("LeftButton");
	
	-- Set the start and stop moving events on triggered events
	this:SetScript(SCRIPTHANDLER_ON_DRAG_START, _startMoving);
	this:SetScript(SCRIPTHANDLER_ON_DRAG_STOP, _stopMovingOrSizing);
	
	-- Make the frame react to the mouse
	this:EnableMouse(true);
	
	-- Make the frame movable
	this:SetMovable(true);
	
	_db[IS_ADDON_LOCKED] = false;
	
	_report("is now", "Unlocked");

end

--------

local _lockAddon = function()
	
	-- Stop the frame from being movable
	this:SetMovable(false);

	-- Remove all buttons from triggering drag events
	this:RegisterForDrag();
	
	-- Nil the 'OnSragStart' script event
	this:SetScript(SCRIPTHANDLER_ON_DRAG_START, nil);
	this:SetScript(SCRIPTHANDLER_ON_DRAG_STOP, nil);
	
	-- Disable mouse interactivity on the frame
	this:EnableMouse(false)

	_db[IS_ADDON_LOCKED] = true;
	
	_report("is now", "Locked");
	
end

--------

local _toggleLockToScreen = function()

	-- Inversed logic to lock the addon if _db[IS_ADDON_LOCKED] returns 'nil' for some reason.
	if not _db[IS_ADDON_LOCKED] then
	
		_lockAddon();
	
	else
	
		_unlockAddon();
	
	end

end

--------

local _loadProfileID = function()

	_unit_name = UnitName("player");
	_realm_name = GetRealmName();
	_profile_id = _unit_name .. "-" .. _realm_name;
	
end

--------

local _loadSavedVariables = function()

	-- First time install
	if not FisherDB then
		FisherDB = {};
	end
	
	-- this should produce an error if _profile_id is not yet set, as is intended.
	_db = FisherDB[_profile_id];
	
	-- This means we have a new char.
	if not _db then
		_db = _default_db
	end
	
	-- In this case we have a player with an older version DB.
	if (not _db[DB_VERSION]) or (_db[DB_VERSION] < _default_db[DB_VERSION]) then
		
		-- For now we just blindly attempt to merge.
		_db = merge(_default_db, _db);
		
	end
	
	_mh_ench_max_charges = _db[MH_ENCHANT_CURRENT_CHARGES];
	_oh_ench_max_charges = _db[OH_ENCHANT_CURRENT_CHARGES];
	_mh_ench_expiration	= _db[MH_ENCHANT_CURRENT_EXPIRATION];
	_oh_ench_expiration = _db[OH_ENCHANT_CURRENT_EXPIRATION];

end

--------

local _finishInitialisation = function()
	
	-- we only need this once
	this:UnregisterEvent("PLAYER_LOGIN");
	
	_validateWeaponEnchants();

end

--------

local _storeLocalDatabaseToSavedVariables = function()
	
	-- #OPTION: We could have local variables for lots of DB
	-- 			stuff that we can load into the _db Object
	--			before we store it.
	--
	--			Should probably make a list of variables to keep
	--			track of which changed and should be updated.
	--			Something we can just loop through so load and
	--			unload never desync.
	
	_db[MH_ENCHANT_CURRENT_CHARGES] = _mh_ench_max_charges or 0;
	_db[OH_ENCHANT_CURRENT_CHARGES] = _oh_ench_max_charges or 0;
	_db[MH_ENCHANT_CURRENT_EXPIRATION] = _mh_ench_expiration or 0;
	_db[OH_ENCHANT_CURRENT_EXPIRATION] = _oh_ench_expiration or 0;
	
	-- Commit to local storage
	FisherDB[_profile_id] = _db;

end

--------

local _loadOptions = function()

	-- This is where I intend to fire off calls to Setters for "Active" "locked" etc.

end

--------

local _populateRequiredEvents = function()
	
	_addEvent("BAG_UPDATE_COOLDOWN", _validateWeaponEnchants);
	_addEvent("UNIT_INVENTORY_CHANGED", _validateWeaponEnchants);
	
	_addEvent("PLAYER_LOGIN", _finishInitialisation);
	
end

--------

local _createMHProgressBar = function()

	-- We already made one, no use in making another.
	if _mh_progress_bar then
	
		return;
	
	end
	
	_mh_progress_bar = CreateFrame("FRAME", nil, this);
	
	_mh_progress_bar:SetBackdrop(
		{
			["bgFile"] = "Interface/CHATFRAME/CHATFRAMEBACKGROUND"
		}
	);
	
	_mh_progress_bar:SetBackdropColor(0, 0.5, 0, 1);
	
	_mh_progress_bar:SetWidth(_db[BAR_WIDTH]);
	_mh_progress_bar:SetHeight(_db[BAR_HEIGHT]);
	
	_mh_progress_bar:SetPoint("TOPLEFT", 1, -1);

end

--------

local _createOHProgressBar = function()

	-- We already made one, no use in making another.
	if _oh_progress_bar then
	
		return;
	
	end
	
	_oh_progress_bar = CreateFrame("FRAME", nil, this);
	
	_oh_progress_bar:SetBackdrop(
		{
			["bgFile"] = "Interface/CHATFRAME/CHATFRAMEBACKGROUND"
		}
	);
	
	_oh_progress_bar:SetBackdropColor(0, 0.5, 0, 1);
	
	_oh_progress_bar:SetWidth(_db[BAR_WIDTH]);
	_oh_progress_bar:SetHeight(_db[BAR_HEIGHT]);
	
	_oh_progress_bar:SetPoint("BOTTOMLEFT", 1, 1);

end

--------

local _constructAddon = function()

	this:SetWidth(_db[BAR_WIDTH] + 2); -- add margin left n right
	this:SetHeight(_db[BAR_HEIGHT] * 2 + 3); -- 2 bars, 1 px margin top, centre, bottom
	
	this:SetBackdrop(
		{
			["bgFile"] = "Interface/CHATFRAME/CHATFRAMEBACKGROUND"
		}
	);
	
	this:SetBackdropColor(0, 0, 0, 1);
	
	this:SetPoint(_db[POSITION_POINT], _db[POSITION_X], _db[POSITION_Y]);
	
	if (not _db[IS_ADDON_LOCKED]) then _unlockAddon() end;
	
	-- CREATE CHILDREN
	_createMHProgressBar();
	_createOHProgressBar();

	_populateRequiredEvents();
	
end

--------

local _removeEvents = function()

	for event_name, eventHandler in pairs(_event_handlers) do
	
		if eventHandler then
		
			_removeEvent(event_name);
		
		end
	
	end

end

--------

local _destructAddon = function()

	-- Remove all registered events
	_removeEvents();
	
end

--------

local _activateAddon = function()

	if _db[IS_ADDON_ACTIVATED] then
	
		return;
	
	end

	_constructAddon();

	_db[IS_ADDON_ACTIVATED] = true;
	
	_report("is now", "Activated");
		
end

--------

local _deactivateAddon = function()

	if not _db[IS_ADDON_ACTIVATED] then
	
		return;
	
	end

	_destructAddon();
	
	_db[IS_ADDON_ACTIVATED] = false;

	-- This is here and not in the destructor because
	-- _loadSavedVariables is not in the constructor either.
	_storeLocalDatabaseToSavedVariables();
	
	_report("is now", "Deactivated");
	
end

--------

local _toggleAddonActivity = function()

	if not _db[IS_ADDON_ACTIVATED] then
		
		_activateAddon();
		
	else
	
		_deactivateAddon();
		
	end

end

--------

local _slashCmdHandler = function(message, chat_frame)

	local _,_,command_name, params = stringFind(message, "^(%S+) *(.*)");
	
	command_name = tostring(command_name);
	
	local command = _command_list[command_name];
	
	if (command) then
		
		if (type(command.execute) ~= "function") then
			
			error("Attempt to execute slash command without execution function.");
			
		end
		
		command.execute(params);

	else
		-- prt("Print our available command list.");
		_printSlashCommandList();
		
	end
		
end

--------

local _addSlashCommand = function(name, command, command_description, db_property)

	-- prt("Adding a slash command");
	if 	(not name)
	or	(name == "")
	or	(not command)
	or 	(type(command) ~= "function")
	or 	(not command_description)
	or 	(command_description == "") then
	
		error("Usage: _addSlashCommand(name <string>, command <function>, command_description <string> [, db_property <string>])");
	
	end
	
	-- prt("Creating a slash command object into the command list");
	_command_list[name] = {
		["execute"] = command,
		["description"] = command_description
	};
	
	if (db_property) then
	
		if (type(db_property) ~= "string" or db_property == "") then
	
			error("db_property must be a non-empty string.");
			
		end
		
		if (_db[db_property] == nil) then
		
			error('The interal database property: "' .. db_property .. '" could not be found.');
		
		end
		-- prt("Add the database property to the command list");
		_command_list[name]["value"] = db_property;
	
	end
	
end

--------


local _populateSlashCommandList = function()

	-- For now we just reset this thing.
	_command_list = {};
	
	_addSlashCommand(
		"lock",
		_toggleLockToScreen,
		'<|cff9999fftoggle|r> |cff999999-- Toggle whether the bars are locked to the screen.|r',
		IS_ADDON_LOCKED
	);
		
	_addSlashCommand(
		"activate",
		_toggleAddonActivity,
		'<|cff9999fftoggle|r> |cff999999-- Toggle whether the AddOn itself is active.|r',
		IS_ADDON_ACTIVATED
	);
	
end

--------

local _initialise = function()
	
	this:UnregisterEvent(_initialisation_event);
	
	_loadProfileID();
	_loadSavedVariables();
	_loadOptions();
	
	_event_handlers = {};
	
	_populateSlashCommandList();
	
	this:SetScript(SCRIPTHANDLER_ON_EVENT, _eventCoordinator);
	
	_addEvent("PLAYER_LOGOUT", _storeLocalDatabaseToSavedVariables);
	
	if _db[IS_ADDON_ACTIVATED] then
	
		_constructAddon();
	
	end
		
end

--------

-- And add a handler to react on the above matches.
SlashCmdList["FISHER"] = _slashCmdHandler;

this:SetScript("OnEvent", _initialise);
this:RegisterEvent(_initialisation_event);