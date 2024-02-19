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
	encode( 1, -1),
	encode( 1,  0),
	encode( 0,  1),
	encode(-1,  1),
	encode(-1,  0),
	encode( 0, -1),
}

M.directions_xy = {
	 1, -1,
	 1,  0,
	 0,  1,
	-1,  1,
	-1,  0,
	 0, -1,
}

M.diagonals = {
	encode( 2, -1),
	encode( 1,  1),
	encode(-1,  2),
	encode(-2,  1),
	encode(-1, -1),
	encode( 1, -2),
}

M.half_axes = {
	encode( 0,  1),
	encode(-1,  0),
	encode( 1, -1),
}

M.edge_directions = {
	{
		encode( 1, -1),
		encode( 1,  0),
		encode(-1,  1),
		encode(-1,  0),
	},
	{
		encode( 0,  1),
		encode(-1,  1),
		encode( 0, -1),
		encode( 1, -1),
	},
	{
		encode(-1,  0),
		encode( 0, -1),
		encode( 1,  0),
		encode( 0,  1),
	},
}

M.edge_directions_xy = {
	{
		 1, -1,
		 1,  0,
		-1,  1,
		-1,  0,
	},
	{
		 0,  1,
		-1,  1,
		 0, -1,
		 1, -1,
	},
	{
		-1,  0,
		 0, -1,
		 1,  0,
		 0,  1,
	},
}

M.parallel_edge_directions = {
	{
		encode( 0,  2),
		encode( 0, -2),
	},
	{
		encode( 2,  0),
		encode(-2,  0),
	},
	{
		encode( 2, -2),
		encode(-2,  2),
	},
}

function M.create(x, y)
	assert(is_integer(x))
	assert(is_integer(y))

	return encode(x, y)
end

function M.xy(h)
	assert(is_integer(h))

	return decode(h)
end

function M.xyz(h)
	assert(is_integer(h))

	local x, y = decode(h)
	return x, y, -x - y
end

function M.add(a, b)
	assert(is_integer(a))
	assert(is_integer(b))

	local ax, ay = decode(a)
	local bx, by = decode(b)
	return encode(ax + bx, ay + by)
end

function M.split(h)
	assert(is_integer(h))

	local x, y = decode(h)
	local lx = barsh(x, 1)
	local hx = barsh(x + bor(band(x, 1), brsh(x, 31)), 1)
	local ly = barsh(y, 1)
	local hy = barsh(y + bor(band(y, 1), brsh(y, 31)), 1)
	return hx, ly, lx, hy
end

function M.round(x, y, z)
	assert(is_number(x))
	assert(is_number(y))
	assert(is_number(z))

	local xi = math.floor(.5 + x)
	local yi = math.floor(.5 + y)
	local zi = math.floor(.5 + z)
	local x_diff = math.abs(xi - x)
	local y_diff = math.abs(yi - y)
	local z_diff = math.abs(zi - z)
	if x_diff > y_diff and x_diff > z_diff then
		xi = -yi - zi
	else
		if y_diff > z_diff then
			yi = -xi - zi
		else
			zi = -xi - yi
		end
	end
	return xi, yi, zi
end

function M.neighbor(x, y, i)
	assert(is_integer(x))
	assert(is_integer(y))
	assert(is_integer(i))

	local first = (i - 1) * 2 + 1
	return x + M.directions_xy[first], y + M.directions_xy[first + 1]
end

function M.edge_neighbor(x, y, half_axis, i)
	assert(is_integer(x))
	assert(is_integer(y))
	assert(is_integer(half_axis))
	assert(is_integer(i))

	local dirs = M.edge_directions_xy[half_axis]
	local first = (i - 1) * 2 + 1
	return x + dirs[first], y + dirs[first + 1]
end

function M.edge_direction(half_axis, i)
	assert(is_integer(half_axis))
	assert(is_integer(i))

	local dirs = M.edge_directions_xy[half_axis]
	local first = (i - 1) * 2 + 1
	return dirs[first], dirs[first + 1]
end

function M.center_point(x, y, origin, size)
	assert(is_number(x))
	assert(is_number(y))

	local ix = (orientation.f0 * x + orientation.f1 * y) * size.x
	local iy = (orientation.f2 * x + orientation.f3 * y) * size.y
	return ix + origin.x, iy + origin.y
end

function M.from_point(pos, origin, size)
	local pt_x = (pos.x - origin.x) / size.x
	local pt_y = (pos.y - origin.y) / size.y
	local x = orientation.b0 * pt_x + orientation.b1 * pt_y
	local y = orientation.b2 * pt_x + orientation.b3 * pt_y
	return x, y, -x - y
end

function M.direction_vector(ax, ay, bx, by, size)
	assert(is_integer(ax))
	assert(is_integer(ay))
	assert(is_integer(bx))
	assert(is_integer(by))

	local iax = (orientation.f0 * ax + orientation.f1 * ay) * size.x
	local iay = (orientation.f2 * ax + orientation.f3 * ay) * size.y
	local ibx = (orientation.f0 * bx + orientation.f1 * by) * size.x
	local iby = (orientation.f2 * bx + orientation.f3 * by) * size.y
	local x = ibx - iax
	local y = iby - iay
	local f = 1 / math.sqrt(x * x + y * y)
	return x * f, y * f
end

function M.generate_grid(radius, fn)
	assert(is_integer(radius))
	assert(is_callable(fn))

	for x = -radius, radius do
		local y1 = math.max(-radius, -x - radius)
		local y2 = math.min( radius, -x + radius)
		for y = y1, y2 do
			fn(encode(x, y), x, y, -x - y)
		end
	end
end

return M
