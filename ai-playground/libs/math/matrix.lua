-- {{{ Matrix operations library
-- Mathematical foundation for neural network computations

local Matrix = {}
Matrix.__index = Matrix

-- {{{ Matrix constructor
function Matrix:new(rows, cols, data)
    local obj = {
        rows = rows or 0,
        cols = cols or 0,
        data = data or {}
    }
    
    -- Initialize with zeros if no data provided
    if not data then
        obj.data = {}
        for i = 1, rows do
            obj.data[i] = {}
            for j = 1, cols do
                obj.data[i][j] = 0
            end
        end
    end
    
    setmetatable(obj, self)
    return obj
end
-- }}}

-- {{{ Matrix creation utilities
function Matrix.zeros(rows, cols)
    return Matrix:new(rows, cols)
end

function Matrix.ones(rows, cols)
    local matrix = Matrix:new(rows, cols)
    for i = 1, rows do
        for j = 1, cols do
            matrix.data[i][j] = 1
        end
    end
    return matrix
end

function Matrix.random(rows, cols, min, max)
    min = min or -1
    max = max or 1
    local matrix = Matrix:new(rows, cols)
    for i = 1, rows do
        for j = 1, cols do
            matrix.data[i][j] = min + (max - min) * math.random()
        end
    end
    return matrix
end

function Matrix.identity(size)
    local matrix = Matrix:new(size, size)
    for i = 1, size do
        matrix.data[i][i] = 1
    end
    return matrix
end

function Matrix.from_array(array, rows, cols)
    rows = rows or #array
    cols = cols or 1
    local matrix = Matrix:new(rows, cols)
    
    if cols == 1 then
        -- Column vector
        for i = 1, rows do
            matrix.data[i][1] = array[i] or 0
        end
    else
        -- 2D array
        local idx = 1
        for i = 1, rows do
            for j = 1, cols do
                matrix.data[i][j] = array[idx] or 0
                idx = idx + 1
            end
        end
    end
    return matrix
end
-- }}}

-- {{{ Matrix properties and access
function Matrix:get(row, col)
    if row < 1 or row > self.rows or col < 1 or col > self.cols then
        error("Matrix index out of bounds")
    end
    return self.data[row][col]
end

function Matrix:set(row, col, value)
    if row < 1 or row > self.rows or col < 1 or col > self.cols then
        error("Matrix index out of bounds")
    end
    self.data[row][col] = value
end

function Matrix:size()
    return self.rows, self.cols
end

function Matrix:is_square()
    return self.rows == self.cols
end
-- }}}

-- {{{ Matrix arithmetic operations
function Matrix:add(other)
    if type(other) == "number" then
        -- Scalar addition
        local result = Matrix:new(self.rows, self.cols)
        for i = 1, self.rows do
            for j = 1, self.cols do
                result.data[i][j] = self.data[i][j] + other
            end
        end
        return result
    else
        -- Matrix addition
        if self.rows ~= other.rows or self.cols ~= other.cols then
            error("Matrix dimensions must match for addition")
        end
        local result = Matrix:new(self.rows, self.cols)
        for i = 1, self.rows do
            for j = 1, self.cols do
                result.data[i][j] = self.data[i][j] + other.data[i][j]
            end
        end
        return result
    end
end

function Matrix:subtract(other)
    if type(other) == "number" then
        -- Scalar subtraction
        local result = Matrix:new(self.rows, self.cols)
        for i = 1, self.rows do
            for j = 1, self.cols do
                result.data[i][j] = self.data[i][j] - other
            end
        end
        return result
    else
        -- Matrix subtraction
        if self.rows ~= other.rows or self.cols ~= other.cols then
            error("Matrix dimensions must match for subtraction")
        end
        local result = Matrix:new(self.rows, self.cols)
        for i = 1, self.rows do
            for j = 1, self.cols do
                result.data[i][j] = self.data[i][j] - other.data[i][j]
            end
        end
        return result
    end
end

function Matrix:multiply(other)
    if type(other) == "number" then
        -- Scalar multiplication
        local result = Matrix:new(self.rows, self.cols)
        for i = 1, self.rows do
            for j = 1, self.cols do
                result.data[i][j] = self.data[i][j] * other
            end
        end
        return result
    else
        -- Matrix multiplication
        if self.cols ~= other.rows then
            error(string.format("Cannot multiply matrices: %dx%d * %dx%d", 
                  self.rows, self.cols, other.rows, other.cols))
        end
        local result = Matrix:new(self.rows, other.cols)
        for i = 1, self.rows do
            for j = 1, other.cols do
                local sum = 0
                for k = 1, self.cols do
                    sum = sum + self.data[i][k] * other.data[k][j]
                end
                result.data[i][j] = sum
            end
        end
        return result
    end
end

function Matrix:hadamard(other)
    if self.rows ~= other.rows or self.cols ~= other.cols then
        error("Matrix dimensions must match for element-wise multiplication")
    end
    local result = Matrix:new(self.rows, self.cols)
    for i = 1, self.rows do
        for j = 1, self.cols do
            result.data[i][j] = self.data[i][j] * other.data[i][j]
        end
    end
    return result
end
-- }}}

-- {{{ Matrix transformations
function Matrix:transpose()
    local result = Matrix:new(self.cols, self.rows)
    for i = 1, self.rows do
        for j = 1, self.cols do
            result.data[j][i] = self.data[i][j]
        end
    end
    return result
end

function Matrix:map(func)
    local result = Matrix:new(self.rows, self.cols)
    for i = 1, self.rows do
        for j = 1, self.cols do
            result.data[i][j] = func(self.data[i][j])
        end
    end
    return result
end

function Matrix:apply(func)
    for i = 1, self.rows do
        for j = 1, self.cols do
            self.data[i][j] = func(self.data[i][j])
        end
    end
    return self
end
-- }}}

-- {{{ Matrix utility functions
function Matrix:to_array()
    local array = {}
    for i = 1, self.rows do
        for j = 1, self.cols do
            table.insert(array, self.data[i][j])
        end
    end
    return array
end

function Matrix:copy()
    local result = Matrix:new(self.rows, self.cols)
    for i = 1, self.rows do
        for j = 1, self.cols do
            result.data[i][j] = self.data[i][j]
        end
    end
    return result
end

function Matrix:print()
    print(string.format("Matrix %dx%d:", self.rows, self.cols))
    for i = 1, self.rows do
        local row_str = "["
        for j = 1, self.cols do
            row_str = row_str .. string.format("%8.3f", self.data[i][j])
            if j < self.cols then
                row_str = row_str .. ", "
            end
        end
        row_str = row_str .. "]"
        print(row_str)
    end
end

function Matrix:sum()
    local total = 0
    for i = 1, self.rows do
        for j = 1, self.cols do
            total = total + self.data[i][j]
        end
    end
    return total
end

function Matrix:max()
    local max_val = -math.huge
    for i = 1, self.rows do
        for j = 1, self.cols do
            if self.data[i][j] > max_val then
                max_val = self.data[i][j]
            end
        end
    end
    return max_val
end

function Matrix:min()
    local min_val = math.huge
    for i = 1, self.rows do
        for j = 1, self.cols do
            if self.data[i][j] < min_val then
                min_val = self.data[i][j]
            end
        end
    end
    return min_val
end
-- }}}

-- {{{ Operator overloading
Matrix.__add = Matrix.add
Matrix.__sub = Matrix.subtract
Matrix.__mul = Matrix.multiply

function Matrix.__tostring(matrix)
    local str = string.format("Matrix %dx%d:\n", matrix.rows, matrix.cols)
    for i = 1, matrix.rows do
        str = str .. "["
        for j = 1, matrix.cols do
            str = str .. string.format("%8.3f", matrix.data[i][j])
            if j < matrix.cols then
                str = str .. ", "
            end
        end
        str = str .. "]\n"
    end
    return str
end
-- }}}

return Matrix
-- }}}