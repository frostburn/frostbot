module heuristic;

import std.stdio;
import std.string;
import std.math;

import board8;

struct Grid
{
    float[] values;

    size_t width;
    size_t height;

    this(size_t width, size_t height)
    {
        this.width = width;
        this.height = height;
        values.length = width * height;
        values[] = 0;
    }

    this(Board8 playing_area, Board8 player, Board8 opponent)
    {
        init!Board8(playing_area, player, opponent);
    }

    void init(T)(in T playing_area,in T player,in T opponent)
    {
        width = playing_area.horizontal_extent;
        height = playing_area.vertical_extent;
        values.length = width * height;
        foreach (y; 0..height){
            foreach(x; 0..width){
                T p = T(x, y);
                if (p & playing_area){
                    if (p & player){
                        values[x + y * width] = 1;
                    }
                    else if (p & opponent){
                        values[x + y * width] = -1;
                    }
                    else{
                        values[x + y * width] = 0;
                    }
                }
                else{
                    values[x + y * width] = float.nan;
                }
            }
        }
    }

    void neighbours(size_t index, out float north, out float west, out float south, out float east)
    {
            if (index >= width){
                north = values[index - width];
                if (north.isNaN){
                    north = 0;
                }
            }
            else{
                north = 0;
            }
            if (index % width > 0){
                west = values[index - 1];
                if (west.isNaN){
                    west = 0;
                }
            }
            else{
                west = 0;
            }
            if (index / width < height - 1){
                south = values[index + width];
                if (south.isNaN){
                    south = 0;
                }
            }
            else{
                south = 0;
            }
            if (index % width != width - 1){
                east = values[index + 1];
                if (east.isNaN){
                    east = 0;
                }
            }
            else{
                east = 0;
            }
    }

    void bouzy_dilate()
    {
        float[] new_values;
        new_values.length = values.length;
        foreach (index, value; values){
            float north, west, south, east;
            neighbours(index, north, west, south, east);
            float sgn_total = sgn(north) + sgn(west) + sgn(south) + sgn(east);
            if (value >= 0 && north >= 0 && west >= 0 && south >= 0 && east >= 0){
                new_values[index] = value + sgn_total;
            }
            else if (value <= 0 && north <= 0 && west <= 0 && south <= 0 && east <= 0){
                new_values[index] = value + sgn_total;
            }
            else{
                new_values[index] = value;
            }
        }
        values = new_values;
    }

    void bouzy_erode()
    {
        float[] new_values;
        new_values.length = values.length;
        foreach (index, value; values){
            float north, west, south, east;
            neighbours(index, north, west, south, east);
            if (value > 0){
                foreach (n; [north, west, south, east]){
                    if (n <= 0){
                        value -= 1;
                    }
                }
                if (value < 0){
                    value = 0;
                }
                new_values[index] = value;
            }
            else if (value < 0){
                foreach (n; [north, west, south, east]){
                    if (n >= 0){
                        value += 1;
                    }
                }
                if (value > 0){
                    value = 0;
                }
                new_values[index] = value;
            }
            else{
                new_values[index] = value;
            }
        }
        values = new_values;
    }

    bool radiate()
    {
        bool changed = false;
        float[] new_values;
        new_values.length = values.length;
        foreach (index, value; values){
            float north, west, south, east;
            neighbours(index, north, west, south, east);
            if (value == 0){
                if ((north > 0 || west > 0 || south > 0 || east > 0) && north >= 0 && west >= 0 && south >= 0 && east >= 0){
                    new_values[index] = 1;
                    changed = true;
                }
                else if ((north < 0 || west < 0 || south < 0 || east < 0) && north <= 0 && west <= 0 && south <= 0 && east <= 0){
                    new_values[index] = -1;
                    changed = true;
                }
                else{
                    new_values[index] = 0;
                }
            }
            else{
                new_values[index] = value;
            }
        }
        values = new_values;
        return changed;
    }

    void bouzy(size_t d=3, size_t e=4)
    {
        foreach (i; 0..d){
            bouzy_dilate;
        }
        foreach (i; 0..e){
            bouzy_erode;
        }
    }

    void divide_by_influence()
    {
        while (radiate) {
        }
    }

    string toString()
    {
        string r;
        foreach (y; 0..height){
            foreach (x; 0..width){
                auto value = values[x + y * width];
                if (value < 0){
                    r ~= "\x1b[34m";
                }
                else if (value > 0){
                    r ~= "\x1b[31m";
                }
                else{
                    r ~= "\x1b[0m";
                }
                if (value.isNaN){
                    r ~= "          ";
                }
                else{
                    r ~= format("%+#g  ", value);
                }
            }
            if (y < height - 1){
                r ~= "\n";
            }
        }
        r ~= "\x1b[0m";
        return r;
    }

    void to_boards(T)(out T player, out T opponent)
    {
        player = T.init;
        opponent = T.init;
        foreach (index, value; values){
            auto x = index % width;
            auto y = index / width;
            if (value > 0){
                player |= T(x, y);
            }
            else if(value < 0){
                opponent |= T(x, y);
            }
        }
    }

    float score()
    {
        float result = 0;
        foreach (value; values){
            if (!value.isNaN){
                result += sgn(value);
            }
        }
        return result;
    }
}

void divide_by_influence(T)(T playing_area, ref T player, ref T opponent)
{
    T temp_player;
    T temp_opponent;

    do{
        temp_player = player;
        temp_opponent = opponent;

        T player_cross = player.cross_unsafe;
        T opponent_cross = opponent.cross_unsafe;
        T territory = ~(player_cross & opponent_cross);

        player |= player_cross & playing_area & territory;
        opponent |= opponent_cross & playing_area & territory;
    } while (player != temp_player || opponent != temp_opponent);
}

float heuristic_value(T)(T playing_area, T player, T opponent)
{
    float initial_score = (player | player.liberties(playing_area & ~opponent)).popcount - (opponent | opponent.liberties(playing_area & ~player)).popcount;
    if (!player && !opponent){
        return 5.0;
    }
    if (!player && opponent.popcount == 1){
        return -5.0;
    }

    auto grid = Grid(playing_area, player, opponent);
    grid.bouzy;
    grid.to_boards(player, opponent);
    divide_by_influence(playing_area, player, opponent);
    return player.popcount - opponent.popcount + 0.4 * (opponent.euler - player.euler) + 0.25 * initial_score;
}


/*
unittest
{
    Board8 playing_area = rectangle8(8, 7) & ~ Board8(0, 0);
    Board8 player = Board8(3, 3) | Board8(3, 4) | Board8(3, 5);
    Board8 opponent = Board8(4, 3) | Board8(5, 4);

    auto g = Grid(playing_area, player, opponent);
    g.bouzy;
    g.divide_by_influence;

    assert(g.score == heuristic_value(playing_area, player, opponent));
}
*/