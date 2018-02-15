IdlePollPeriod = 1.0
MovingPollPeriod = 0.25
ForcedFastPolls = 2

InTerminator = "\n"
OutTerminator = "\n"

homed = false
rotation = false
holdtime = 0

function getSingleVal(command)
	local readback = asyn.writeread( string.format(":%s%d", command, CHANNEL), PORT )

	return tonumber( string.match(readback, ":[A-Z]+-?%d+,(-?%d+)"))
end

function home(minVel, maxVel, accel, forwards)
	homed = true

	local typeID   = getSingleVal("GST")

	if ((typeID == 2) or (typeID == 8) or (typeID == 14) or (typeID == 16) or (typeID == 20) or (typeID == 22) or (typeID == 23) or ((typeID >= 25) and (typeID <= 29))) then
		rotation = true
	end

	asyn.writeread( string.format(":SCLS%d,%d" ,CHANNEL, maxVel), PORT)
end


function getAngle()
	local readback = asyn.writeread( string.format(":GA%d", CHANNEL), PORT)

	local match1, match2 = string.match(readback, ":[A-Z]+-?%d+,(-?%d+),(-?%d+)")

	return tonumber(match1), tonumber(match2)
end

function move(position, relative, minVel, maxVel, accel)
	local command = ""

	if relative and rotation then
		command = ":MAR%d,%d,%d,%d"
	elseif relative and not rotation then
		command = ":MPR%d,%d,%d"
	elseif not relative and rotation then
		command = ":MAA%d,%d,%d,%d"
	elseif not relative and not rotation then
		command = ":MPA%d,%d,%d"
	end

	asyn.writeread( string.format(":SCLS%d,%f", CHANNEL, maxVel), PORT)

	local rpos = math.floor(position + 0.5)

	if rotation then
		local angle = rpos % 360000000
		local rev   = math.floor(rpos / 360000000)

		if angle < 0 then
			angle = angle + 360000000
			rev = rev - 1
		end

		asyn.writeread( string.format(command, CHANNEL, angle, rev, holdtime), PORT)
	else
		asyn.writeread( string.format(command, CHANNEL, math.floor(position), holdtime), PORT)
	end
end


function moveVelocity(minVel, maxVel, accel)
	local speed = math.floor(math.abs(maxVel))

	if speed == 0 then
		asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STOP", 1)
		asyn.callParamCallbacks(DRIVER, AXIS)
		return
	end

	local target_pos = 1000000000

	if maxVel < 0 then
		target_pos = - target_pos
	end

	asyn.writeread( string.format(":SCLS%d,%d", CHANNEL, maxVel), PORT)
	asyn.writeread( string.format(":MPR%d,%d,0", CHANNEL, target_pos), PORT)
end


function setPosition(position)
	local rpos = math.floor(position + 0.5)

	if rotation then
		if (rpos < 0.0) or (rpos >= 360000000) then
			return
		end
	end

	asyn.writeread( string.format(":SP%d,%d", CHANNEL ,rpos), PORT)
end


function poll()
	if (homed ~= true) then
		return false
	end

	local pos = 0

	if rotation then
		local angle, rev = getAngle()

		pos = rev * 360000000 + angle
	else
		pos = getSingleVal("GP")
	end

	asyn.setDoubleParam( DRIVER, AXIS, "MOTOR_POSITION", pos)
	asyn.setDoubleParam( DRIVER, AXIS, "MOTOR_ENCODER_POSITION", pos)

	local status = getSingleVal("GS")

	local moving = 0

	--Holding
	if status == 3 then
		if holdtime ~= 60000 then
			moving = 1
		end
	elseif (status > 0) and (status <= 9) then
		moving = 1
	end

	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_DONE",       moving ~ 1)
	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_MOVING",     moving)

	local know_pos = getSingleVal("GPPK")

	asyn.setIntegerParam( DRIVER, AXIS, "MOTOR_STATUS_HOMED", know_pos)

	asyn.callParamCallbacks(DRIVER, AXIS)

	return (moving == 1)
end


function stop(acceleration)
	asyn.writeread( string.format(":S%d", CHANNEL), PORT)
end
