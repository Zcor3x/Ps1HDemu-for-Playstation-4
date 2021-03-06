-- Lua 5.3
-- Title:   Medievil - SCES-01492 (EU-FR)
-- Author:  Ernesto Corvi

-- Changelog:

apiRequest(1.0)	-- request version 1.0 API. Calling apiRequest() is mandatory.

local emu	= getEmuObject() -- emulator
local cpu	= getR3KObject() -- cpu

emu.PadSetButtonsMode(2) -- switch Select/Start -> Touchpad/Options mode

local showingConfirmation = false
local needsReinit = false
local hooks = {0, 0, 0, 0}

function vTLSetupSelOptionsStone() -- tail end of vTLSetupSelOptionsStone
	
	-- turn on triangle
	local gulButtonHelpMask = cpu.GetGpr(gpr.v0)
	gulButtonHelpMask = gulButtonHelpMask + 2
	cpu.SetGpr(gpr.v0, gulButtonHelpMask)
	
--	emu.Log(string.format("gulButtonHelpMask = %d", gulButtonHelpMask))
	
	-- associate 'Exit' message
	cpu.WriteMem32(0x800EF774, 0x800EDB0C)
end

function vTLUpdateSelOptionsStone() -- tail end of vTLUpdateSelOptionsStone
	local buttons = emu.PadRead()
	
--	emu.Log(string.format("buttons = %08x", buttons))
	
	if showingConfirmation == false and (buttons & 0x1000) ~= 0 then
		cpu.SetPC(0x8006DD88) -- vPauseExitX
		showingConfirmation = true
	elseif needsReinit == true then
		cpu.SetPC(0x80014148) -- vTLUpdateSelOptionsStone
		needsReinit = false
	elseif showingConfirmation == true then
		cpu.SetPC(cpu.GetGpr(gpr.ra))
	end
end

function xHelpProcessChoiceSelectionNo() -- start of xHelpProcessChoiceSelection
	if showingConfirmation == true then
		showingConfirmation = false
		needsReinit = true
	end
end

function xGameFadeUpdate() -- end of xGameFadeUpdate
	if showingConfirmation == true then
		showingConfirmation = false
		needsReinit = true
		emu.Launch("/app0/eboot.bin")
	end
end

function install_title_hooks()
	hooks[1] = cpu.AddHook(0x80014298, 0x34420001, vTLSetupSelOptionsStone)
	hooks[2] = cpu.AddHook(0x800142B8, 0x3C02800F, vTLUpdateSelOptionsStone)
	hooks[3] = cpu.AddHook(0x80063C74, 0x00002821, xHelpProcessChoiceSelectionNo)
	hooks[4] = cpu.AddHook(0x8004EAE0, 0xAF800574, xGameFadeUpdate)
	showingConfirmation = false
	needsReinit = false
end

function remove_title_hooks()
	for i=1,4 do
		if hooks[i] ~= 0 then
			cpu.RemoveHook(hooks[i])
			hooks[i] = 0
		end
	end
end


-- Remap font render to texture VRAM area to frame buffer
function MR_LoadOverlay() -- MR_LoadOverlay
	local overlay = cpu.GetGpr(gpr.a0)
--	emu.Log(string.format("Overlay: %02x", overlay))

	if overlay == 0x15 then
--		emu.Log("Hooking FB Mapping")
		emu.AddFBMapping(768,256, 180, 256)
		install_title_hooks()
	else
--		emu.Log("Removing FB Mapping")
		emu.RemoveFBMapping(768, 256)
		remove_title_hooks()
	end
	
	-- always flush cache on overlay loads
	cpu.FlushCache()
end

cpu.AddHook(0x800A90D0, 0x27BDFFD0, MR_LoadOverlay)


function boot() -- _start
	-- patch save game sku id
	cpu.WriteMemStrZ(0x800C662C, "BESCES-00311")
end

cpu.AddHook(0x80099B34, 0x3C02800F, boot)
