-- {{{ game constants
local game = {}

game.COLORS = {
    BLACK = {0, 0, 0},
    WHITE = {1, 1, 1},
    RED = {1, 0, 0},
    GREEN = {0, 1, 0},
    BLUE = {0, 0, 1},
    YELLOW = {1, 1, 0}
}

game.WINDOW = {
    DEFAULT_WIDTH = 1280,
    DEFAULT_HEIGHT = 720,
    MIN_WIDTH = 800,
    MIN_HEIGHT = 600
}

game.LANE = {
    SUB_PATHS = 5,
    SUB_PATH_WIDTH_RATIO = 0.2
}

return game
-- }}}