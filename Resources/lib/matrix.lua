local ffi = require("ffi")
local C = ffi.C
local concat = table.concat
local rand = math.random
local uniform = function(a,b) return (b-a)*rand() + a end

local MATRIX_SIGNATURE = 'MatrixUID'
local TOSTRING_ELEMENT_SEPARATOR = ' '
local TOSTRING_ROWS_SEPARATOR = '\n'

ffi.cdef[[
	typedef struct {
		int nrows, ncols;
		double *u[?];
	} matrix_t;
	void *malloc(size_t size);
	void free(void *p);
]]

local matrix_mt = {
	__add = function(self, B)
		local A = copyMatrix(self)
		for i = 1, self.nrows do
			for j = 1, self.ncols do
				A.u[i][j] = A.u[i][j] + B.u[i][j]
			end
		end
		return A
	end,

	__sub = function(self, B)
		local A = copyMatrix(self)
		for i = 1, self.nrows do
			for j = 1, self.ncols do
				A.u[i][j] = A.u[i][j] - B.u[i][j]
			end
		end
		return A
	end,

	__unm = function(self)
		local A = copyMatrix(self)
		for i = 1, self.nrows do
			for j = 1, self.ncols do
				A.u[i][j] = -A.u[i][j]
			end
		end
		return A
	end,

	__mul = function(self, B)
		local t = type(B)
		local A = copyMatrix(self)
		if t == 'number' then
			for i = 1, self.nrows do
				for j = 1, self.ncols do
					A.u[i][j] = B * A.u[i][j]
				end
			end
		else
			for i = 1, self.nrows do
				for j = 1, self.ncols do
					A.u[i][j] = A.u[i][j] * B.u[i][j]
				end
			end
		end
		return A
	end,

	__gc = function(self)
		C.free(self.u[0])
	end,

	__len = function(self)
		return self.nrows
	end,

	__tostring = function(self)
		local ss = {}
		for i = 1, self.nrows do
			local s = {}
			local v = self.u[i]
			for j = 1, self.ncols do
				s[j] = v[j]
			end
			ss[i] = concat(s, TOSTRING_ELEMENT_SEPARATOR)
		end
		return concat(ss, TOSTRING_ROWS_SEPARATOR)
	end,

	__index = function(self, key)
		return self.u[key]
	end,

	signature = MATRIX_SIGNATURE,
}

local matrix_t = ffi.metatype("matrix_t", matrix_mt)

Matrix = function(arg1, arg2)
	local type1, type2 = type(arg1), type(arg2)
	if type1 == 'number' and type2 == 'number' then
		return newMatrix(arg1, arg2)
	elseif type1 == 'table' then
		return tableMatrix(arg1)
	elseif arg1 and arg1.signature == MATRIX_SIGNATURE then
		return copyMatrix(arg1)
	end
end


newMatrix = function(nrows, ncols)
	local matrix = ffi.new("matrix_t", nrows+1)
	matrix.nrows, matrix.ncols = nrows, ncols
	local p = ffi.cast("double *", C.malloc(ffi.sizeof("double")*(nrows+1)*(ncols+1)))
	assert(p)
	ffi.fill(p, ffi.sizeof("double")*(nrows+1)*(ncols+1))
	for i = 1, nrows do
		matrix.u[i] = p + (ncols+1)*i
	end
	return matrix
end

tableMatrix = function(t)
	nrows, ncols = #t, #t[1]
	local A = newMatrix(nrows, ncols)
	for i = 1, nrows do
		for j = 1, ncols do
			A.u[i][j] = t[i][j]
		end
	end
	return A
end

copyMatrix = function(A)
	local B = newMatrix(A.nrows, A.ncols)
	for i = 1, A.nrows do
		for j = 1, A.ncols do
			B.u[i][j] = A.u[i][j]
		end
	end
	return B
end

randMatrix = function(A, bounds)
	for i = 1, self.nrows do
		for j = 1, self.ncols do
			self.u[i][j] = uniform(bounds[j][1], bounds[j][2])
		end
	end
	return A
end
