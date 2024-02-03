local M = {}

local function is_number(t)
	return type(t) == 'number'
end

local function is_integer(t)
	return type(t) == 'number' and math.ceil(t) == t
end

local function is_hex(t)
	return type(t) == 'userdata'
end

local function is_callable(t)
	if type(t) == 'function' then
		return true
	end
	local mt = getmetatable(t)
	return mt ~= nil and mt.__call ~= nil
end

local orientation = {
	f0 = 3 / 2,
	f1 = 0,
	f2 = math.sqrt(3) / 2,
	f3 = math.sqrt(3),
	b0 = 2 / 3,
	b1 = 0,
	b2 = -1 / 3,
	b3 = math.sqrt(3) / 3,
	start_angle = 0,
}

M.directions = {
	vmath.vector3( 1, -1,  0),
	vmath.vector3( 1,  0, -1),
	vmath.vector3( 0,  1, -1),
	vmath.vector3(-1,  1,  0),
	vmath.vector3(-1,  0,  1),
	vmath.vector3( 0, -1,  1),
}

M.diagonals = {
	vmath.vector3( 2, -1, -1),
	vmath.vector3( 1,  1, -2),
	vmath.vector3(-1,  2, -1),
	vmath.vector3(-2,  1,  1),
	vmath.vector3(-1, -1,  2),
	vmath.vector3( 1, -2,  1),
}

M.half_axes = {
	vmath.vector3( 0,  1, -1),
	vmath.vector3(-1,  0,  1),
	vmath.vector3( 1, -1,  0),
}

M.edge_directions = {
	{
		vmath.vector3( 1, -1,  0),
		vmath.vector3( 1,  0, -1),
		vmath.vector3(-1,  1,  0),
		vmath.vector3(-1,  0,  1),
	},
	{
		vmath.vector3( 0,  1, -1),
		vmath.vector3(-1,  1,  0),
		vmath.vector3( 0, -1,  1),
		vmath.vector3( 1, -1,  0),
	},
	{
		vmath.vector3(-1,  0,  1),
		vmath.vector3( 0, -1,  1),
		vmath.vector3( 1,  0, -1),
		vmath.vector3( 0,  1, -1),
	},
}

M.parallel_edge_directions = {
	{
		vmath.vector3( 0,  2, -2),
		vmath.vector3( 0, -2,  2),
	},
	{
		vmath.vector3( 2,  0, -2),
		vmath.vector3(-2,  0,  2),
	},
	{
		vmath.vector3( 2, -2,  0),
		vmath.vector3(-2,  2,  0),
	},
}

function M.create(x, y, z)
	assert(is_number(x))
	assert(is_number(y))
	assert(is_number(z) or z == nil)

	if not z then
		z = -x - y
	end

	assert(math.floor(.5 + x + y + z) == 0)
	return vmath.vector3(x, y, z)
end

function M.create_hash(x, y, z)
	assert(is_integer(x))
	assert(is_integer(y))
	assert(is_integer(z) or z == nil)

	if not z then
		z = -x - y
	end

	assert(math.floor(x + y + z) == 0)
	return (x + 0x40) + bit.lshift(y + 0x40, 8)
end

function M.from_hash(v)
	assert(is_integer(v))

	local x = bit.band(v, 0xff) - 0x40
	local y = bit.rshift(v, 8) - 0x40
	return vmath.vector3(x, y, -x - y)
end

function M.hash(h)
	assert(is_hex(h))
	assert(is_integer(h.x))
	assert(is_integer(h.y))
	assert(is_integer(h.z))

	return (h.x + 0x40) + bit.lshift(h.y + 0x40, 8)
end

function M.add_hashes(a, b)
	assert(is_integer(a))
	assert(is_integer(b))

	return (a + b) - 0x4040
end

function M.split_hash(h)
	assert(is_integer(h))

	local x = bit.band(h, 0x00fe)
	local lx = bit.rshift(x, 1) + 0x0020
	local hx = lx + bit.band(h, 0x0001)
	local y = bit.band(h, 0xfe00)
	local ly = bit.rshift(y, 1) + 0x2000
	local hy = ly + bit.band(h, 0x0100)
	return hx + ly, lx + hy
end

function M.split(h)
	assert(is_hex(h))

	local x, y = h.x, h.y
	local lx = bit.arshift(x, 1)
	local hx = bit.arshift(x + bit.bor(bit.band(x, 1), bit.rshift(x, 31)), 1)
	local ly = bit.arshift(y, 1)
	local hy = bit.arshift(y + bit.bor(bit.band(y, 1), bit.rshift(y, 31)), 1)
	return vmath.vector3(hx, ly, -hx - ly), vmath.vector3(lx, hy, -lx - hy)
end

function M.round(h)
	assert(is_hex(h))

	local xi = math.floor(math.floor(.5 + h.x))
	local yi = math.floor(math.floor(.5 + h.y))
	local zi = math.floor(math.floor(.5 + h.z))
	local x_diff = math.abs(xi - h.x)
	local y_diff = math.abs(yi - h.y)
	local z_diff = math.abs(zi - h.z)
	if x_diff > y_diff and x_diff > z_diff then
		xi = -yi - zi
	else
		if y_diff > z_diff then
			yi = -xi - zi
		else
			zi = -xi - yi
		end
	end
	return vmath.vector3(xi, yi, zi)
end

function M.length(h)
	assert(is_hex(h))

	return math.floor((math.abs(h.x) + math.abs(h.y) + math.abs(h.z)) / 2)
end

function M.distance(a, b)
	assert(is_hex(a))
	assert(is_hex(b))

	return M.length(a - b)
end

function M.neighbor(h, i)
	assert(is_hex(h))
	assert(is_integer(i))

	return h + M.directions[i]
end

function M.diagonal_neighbor(h, i)
	assert(is_hex(h))
	assert(is_integer(i))

	return h + M.diagonals[i]
end

function M.half_axis(h)
	assert(is_hex(h))

	if h.x % 2 == 0 then
		return 1
	elseif h.y % 2 == 0 then
		return 2
	else
		return 3
	end
end

function M.line(a, b)
	assert(is_hex(a))
	assert(is_hex(b))

	local distance = M.distance(a, b)
	local a_nudge = vmath.vector3(a.x + 1e-06, a.y + 1e-06, a.z - 2e-06)
	local b_nudge = vmath.vector3(b.x + 1e-06, b.y + 1e-06, b.z - 2e-06)
	local result = {}
	local step = 1 / math.max(distance, 1)
	for i = 1, distance do
		result[i] = M.round(vmath.lerp(step * (i - 1), a_nudge, b_nudge))
	end
	return result
end

function M.center_point(h, origin, size)
	assert(is_hex(h))

	local x = (orientation.f0 * h.x + orientation.f1 * h.y) * size.x
	local y = (orientation.f2 * h.x + orientation.f3 * h.y) * size.y
	return vmath.vector3(x + origin.x, y + origin.y, 0)
end

function M.from_point(p, origin, size)
	local pt = vmath.vector3((p.x - origin.x) / size.x, (p.y - origin.y) / size.y, 0)
	local x = orientation.b0 * pt.x + orientation.b1 * pt.y
	local y = orientation.b2 * pt.x + orientation.b3 * pt.y
	return vmath.vector3(x, y, -x - y)
end

function M.direction_vector(a, b, size)
	assert(is_hex(a))
	assert(is_hex(b))

	local ax = (orientation.f0 * a.x + orientation.f1 * a.y) * size.x
	local ay = (orientation.f2 * a.x + orientation.f3 * a.y) * size.y
	local bx = (orientation.f0 * b.x + orientation.f1 * b.y) * size.x
	local by = (orientation.f2 * b.x + orientation.f3 * b.y) * size.y
	local x = bx - ax
	local y = by - ay
	local f = 1 / math.sqrt(x * x + y * y)
	return vmath.vector3(x * f, y * f, 0)
end

function M.corner_offset(i, size)
	assert(is_integer(i))

	local angle = 2 * math.pi * (orientation.start_angle - (i - 1)) / 6
	return vmath.vector3(size.x * math.cos(angle), size.y * math.sin(angle), 0)
end

function M.corner_points(h, origin, size)
	assert(is_hex(h))

	local result = {}
	local center = M.center_point(h, origin, size)
	for i = 1, 6 do
		local offset = M.corner_offset(i, size)
		result[i] = vmath.vector3(center.x + offset.x, center.y + offset.y, 0)
	end
	return result
end

function M.generate_grid(radius, fn)
	assert(is_integer(radius))
	assert(is_callable(fn))

	for x = -radius, radius do
		local y1 = math.max(-radius, -x - radius)
		local y2 = math.min( radius, -x + radius)
		for y = y1, y2 do
			local h = vmath.vector3(x, y, -x - y)
			local hh = M.hash(h)
			fn(h, hh)
		end
	end
end

return M
