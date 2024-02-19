local M = {}

local band = bit.band
local bor = bit.bor
local blsh = bit.lshift
local brsh = bit.rshift
local barsh = bit.arshift

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

local encode_lut = {
	    0,    1,    4,    5,   16,   17,   20,   21,
	   64,   65,   68,   69,   80,   81,   84,   85,
	  256,  257,  260,  261,  272,  273,  276,  277,
	  320,  321,  324,  325,  336,  337,  340,  341,
	 1024, 1025, 1028, 1029, 1040, 1041, 1044, 1045,
	 1088, 1089, 1092, 1093, 1104, 1105, 1108, 1109,
	 1280, 1281, 1284, 1285, 1296, 1297, 1300, 1301,
	 1344, 1345, 1348, 1349, 1360, 1361, 1364, 1365,
	 4096, 4097, 4100, 4101, 4112, 4113, 4116, 4117,
	 4160, 4161, 4164, 4165, 4176, 4177, 4180, 4181,
	 4352, 4353, 4356, 4357, 4368, 4369, 4372, 4373,
	 4416, 4417, 4420, 4421, 4432, 4433, 4436, 4437,
	 5120, 5121, 5124, 5125, 5136, 5137, 5140, 5141,
	 5184, 5185, 5188, 5189, 5200, 5201, 5204, 5205,
	 5376, 5377, 5380, 5381, 5392, 5393, 5396, 5397,
	 5440, 5441, 5444, 5445, 5456, 5457, 5460, 5461,
	16384,16385,16388,16389,16400,16401,16404,16405,
	16448,16449,16452,16453,16464,16465,16468,16469,
	16640,16641,16644,16645,16656,16657,16660,16661,
	16704,16705,16708,16709,16720,16721,16724,16725,
	17408,17409,17412,17413,17424,17425,17428,17429,
	17472,17473,17476,17477,17488,17489,17492,17493,
	17664,17665,17668,17669,17680,17681,17684,17685,
	17728,17729,17732,17733,17744,17745,17748,17749,
	20480,20481,20484,20485,20496,20497,20500,20501,
	20544,20545,20548,20549,20560,20561,20564,20565,
	20736,20737,20740,20741,20752,20753,20756,20757,
	20800,20801,20804,20805,20816,20817,20820,20821,
	21504,21505,21508,21509,21520,21521,21524,21525,
	21568,21569,21572,21573,21584,21585,21588,21589,
	21760,21761,21764,21765,21776,21777,21780,21781,
	21824,21825,21828,21829,21840,21841,21844,21845,
}

local decode_lut = {
	 0, 1, 0, 1, 2, 3, 2, 3, 0, 1, 0, 1, 2, 3, 2, 3,
	 4, 5, 4, 5, 6, 7, 6, 7, 4, 5, 4, 5, 6, 7, 6, 7,
	 0, 1, 0, 1, 2, 3, 2, 3, 0, 1, 0, 1, 2, 3, 2, 3,
	 4, 5, 4, 5, 6, 7, 6, 7, 4, 5, 4, 5, 6, 7, 6, 7,
	 8, 9, 8, 9,10,11,10,11, 8, 9, 8, 9,10,11,10,11,
	12,13,12,13,14,15,14,15,12,13,12,13,14,15,14,15,
	 8, 9, 8, 9,10,11,10,11, 8, 9, 8, 9,10,11,10,11,
	12,13,12,13,14,15,14,15,12,13,12,13,14,15,14,15,
	 0, 1, 0, 1, 2, 3, 2, 3, 0, 1, 0, 1, 2, 3, 2, 3,
	 4, 5, 4, 5, 6, 7, 6, 7, 4, 5, 4, 5, 6, 7, 6, 7,
	 0, 1, 0, 1, 2, 3, 2, 3, 0, 1, 0, 1, 2, 3, 2, 3,
	 4, 5, 4, 5, 6, 7, 6, 7, 4, 5, 4, 5, 6, 7, 6, 7,
	 8, 9, 8, 9,10,11,10,11, 8, 9, 8, 9,10,11,10,11,
	12,13,12,13,14,15,14,15,12,13,12,13,14,15,14,15,
	 8, 9, 8, 9,10,11,10,11, 8, 9, 8, 9,10,11,10,11,
	12,13,12,13,14,15,14,15,12,13,12,13,14,15,14,15,
}

local function encode_2byte(x, y)
	assert(0 <= x and x <= 15)
	assert(0 <= y and y <= 15)
	return bor(encode_lut[1 + x], blsh(encode_lut[1 + y], 1))
end

local function encode_4byte(x, y)
	assert(0 <= x and x <= 255)
	assert(0 <= y and y <= 255)
	return bor(
		bor(encode_lut[1 + band(x, 255)], blsh(encode_lut[1 + band(y, 255)], 1)),
		blsh(bor(encode_lut[1 + band(brsh(x, 8), 255)], blsh(encode_lut[1 + band(brsh(y, 8), 255)], 1)), 16))
end

local function decode_2byte(v)
	assert(0 <= v and v <= 255)
	return decode_lut[1 + v], decode_lut[1 + brsh(v, 1)]
end

local function decode_4byte(v)
	assert(0 <= v and v <= 65535)
	return
		bor(decode_lut[1 + band(v, 255)], blsh(decode_lut[1 + band(brsh(v, 8), 255)], 4)),
		bor(decode_lut[1 + band(brsh(v, 1), 255)], blsh(decode_lut[1 + band(brsh(v, 9), 255)], 4))
end

local function encode(x, y)
	x = x < 0 and -2 * x - 1 or 2 * x
	y = y < 0 and -2 * y - 1 or 2 * y
	return encode_4byte(x, y) + 1
end

local function decode(v)
	local x, y = decode_4byte(v - 1)
	x = band(x, 1) ~= 0 and -brsh(x + 1, 1) or brsh(x, 1)
	y = band(y, 1) ~= 0 and -brsh(y + 1, 1) or brsh(y, 1)
	return x, y
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
	return encode(x, y)
end

function M.from_hash(v)
	assert(is_integer(v))

	local x, y = decode(v)
	return vmath.vector3(x, y, -x - y)
end

function M.hash(h)
	assert(is_hex(h))
	assert(is_integer(h.x))
	assert(is_integer(h.y))
	assert(is_integer(h.z))

	return encode(h.x, h.y)
end

function M.add_hashes(a, b)
	assert(is_integer(a))
	assert(is_integer(b))

	local ax, ay = decode(a)
	local bx, by = decode(b)
	return encode(ax + bx, ay + by)
end

function M.split_hash(h)
	assert(is_integer(h))

	local x, y = decode(h)
	local lx = barsh(x, 1)
	local hx = barsh(x + bor(band(x, 1), brsh(x, 31)), 1)
	local ly = barsh(y, 1)
	local hy = barsh(y + bor(band(y, 1), brsh(y, 31)), 1)
	return encode(hx, ly), encode(lx, hy)
end

function M.split(h)
	assert(is_hex(h))

	local x, y = h.x, h.y
	local lx = barsh(x, 1)
	local hx = barsh(x + bor(band(x, 1), brsh(x, 31)), 1)
	local ly = barsh(y, 1)
	local hy = barsh(y + bor(band(y, 1), brsh(y, 31)), 1)
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
