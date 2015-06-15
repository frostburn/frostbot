import std.stdio;
import std.string;
import std.conv;
import std.math;

import utils;
import chess;
import game_node;


// Canonical legal configuration of kings
// TODO
/+
struct KingsPosition
{
    int player;
    int opponent;

    mixin(get_kings_index_table);

    size_t index() const
    out(result)
    {
        assert(result < KINGS_POSITION_TABLE.length);
    }
    body
    {
        return KINGS_INDEX_TABLE[player][opponent];
    }

    static KingsPosition from_index(size_t index)
    in
    {
        assert(index < KINGS_POSITION_TABLE.length);
    }
    body
    {
        return KINGS_POSITION_TABLE[index];
    }

    void get_boards(out ulong player_king, out ulong opponent_king) const
    {
        player_king = 1UL << player;
        opponent_king = 1UL << opponent;
    }

    size_t piece_index(ulong piece)
    {
        auto transformed_index = transform(bitScanForward(piece), player, opponent);
        return _piece_index(transformed_index, KINGS_POSITION_TABLE[index]);
    }

    ulong from_piece_index(size_t piece_index)
    {
        return 1UL << _from_piece_index(piece_index, this);
    }
}


size_t _piece_index(size_t index, KingsPosition kp){
    if (index < kp.player){
        if (index < kp.opponent){
            return index;
        }
        return index - 1;
    }
    else if (index < kp.opponent){
        return index - 1;
    }
    return index - 2;
}

size_t _from_piece_index(size_t index, KingsPosition kp){
    if (index < kp.player){
        if (index < kp.opponent){
            return index;
        }
        return index + 1;
    }
    else if (index < kp.opponent){
        return index + 1;
    }
    return index + 2;
}


enum Transformation {none, mirror_v, mirror_vh, mirror_h, mirror_hd, mirror_d, mirror_vd, mirror_vhd}


int transform(int index, int player, int opponent){
    return 0;
    /*
    if (transformation == Transformation.none){
        return index;
    }
    int x = index & 7;
    int y = index >> 3;
    if (transformation == Transformation.mirror_v){
        return x + 8 * (7 - y);
    }
    else if (transformation == Transformation.mirror_vh){
        return 7 - x + 8 * (7 - y);
    }
    else if (transformation == Transformation.mirror_h){
        return 7 - x + 8 * y;
    }
    else if (transformation == Transformation.mirror_hd){
        return y + 8 * (7 - x);
    }
    else if (transformation == Transformation.mirror_d){
        return y + 8 * x;
    }
    else if (transformation == Transformation.mirror_vd){
        return 7 - y + 8 * x;
    }
    else if (transformation == Transformation.mirror_vhd){
        return 7 - y + 8 * (7 - x);
    }
    assert(false);
    */
}

int canonical_index(int px, int py, int ox, int oy)
{
    int result = px + 8 * (py + 8 * (ox + 8 * oy));
    int temp;
    int tmp;
    //auto current_transformation = Transformation.none;
    //transformation = current_transformation;
    enum compare_and_replace = "
        //current_transformation++;
        temp = px + 8 * (py + 8 * (ox + 8 * oy));
        if (temp < result){
            result = temp;
            //transformation = current_transformation;
        }
    ";

    py = 7 - py;
    oy = 7 - oy;
    mixin(compare_and_replace);
    px = 7 - px;
    ox = 7 - ox;
    mixin(compare_and_replace);
    py = 7 - py;
    oy = 7 - oy;
    mixin(compare_and_replace);
    tmp = px;
    px = py;
    py = tmp;
    tmp = ox;
    ox = oy;
    oy = tmp;
    mixin(compare_and_replace);
    py = 7 - py;
    oy = 7 - oy;
    mixin(compare_and_replace);
    px = 7 - px;
    ox = 7 - ox;
    mixin(compare_and_replace);
    py = 7 - py;
    oy = 7 - oy;
    mixin(compare_and_replace);
    return result;
}

bool legal(int px, int py, int ox, int oy)
{
    return abs(px - ox) > 1 && abs(py - oy) > 1;
}


string get_kings_index_table()
{
    bool[size_t] seen;
    size_t[] canonical_table;
    canonical_table.length = 64 * 64;
    canonical_table[] = 64 * 64;
    KingsPosition[] kings_position_table;
    kings_position_table.length = 231;
    size_t legal_index = 0;
    foreach (player_x; 0..8){
        foreach (player_y; 0..8){
            auto player_index = player_x + player_y * 8;
            foreach (opponent_x; 0..8){
                foreach (opponent_y; 0..8){
                    auto opponent_index = opponent_x + opponent_y * 8;
                    auto c = canonical_index(player_x, player_y, opponent_x, opponent_y);
                    if (c !in seen){
                        if (legal(player_x, player_y, opponent_x, opponent_y)){
                            canonical_table[c] = legal_index;
                            kings_position_table[legal_index] = KingsPosition(player_index, opponent_index);
                            legal_index += 1;
                        }
                        seen[c] = true;
                    }
                }
            }
        }
    }
    size_t[][] kings_index_table;
    kings_index_table.length = 64;
    foreach (player_x; 0..8){
        foreach (player_y; 0..8){
            auto player_index = player_x + player_y * 8;
            kings_index_table[player_index].length = 64;
            foreach (opponent_x; 0..8){
                foreach (opponent_y; 0..8){
                    auto opponent_index = opponent_x + opponent_y * 8;
                    auto c = canonical_index(player_x, player_y, opponent_x, opponent_y);
                    kings_index_table[player_index][opponent_index] = canonical_table[c];
                }
            }
        }
    }
    return "
        static immutable KingsPosition[] KINGS_POSITION_TABLE = %s;
        static immutable size_t[][] KINGS_INDEX_TABLE = %s;
    ".format(kings_position_table, kings_index_table);
}
+/

struct ChessNodeValue
{
    private
    {
        ubyte data = 0;
        ushort _low_distance = ushort.max;
        ushort _high_distance = ushort.max;
    }

    this(float low, float high, float low_distance=float.infinity, float high_distance=float.infinity)
    {
        this.low = low;
        this.high = high;
        this.low_distance = low_distance;
        this.high_distance = high_distance;
    }

    bool opEquals(in ChessNodeValue rhs) const pure nothrow @nogc @safe
    {
        return data == rhs.data && _low_distance == rhs._low_distance && _high_distance == rhs._high_distance;
    }

    bool initialized()
    {
        return data != 0;
    }

    float low() const @property
    {
        auto ldata = data & 7;
        if (ldata == 1){
            return -float.infinity;
        }
        else if (ldata == 2){
            return -2;
        }
        else if (ldata == 3){
            return -1;
        }
        else if (ldata == 4){
            return 0;
        }
        else if (ldata == 5){
            return 1;
        }
        else if (ldata == 6){
            return 2;
        }
        else {
            return float.nan;
        }
    }

    float low(float value) @property
    {
        ubyte ldata;
        if (value == -float.infinity){
            ldata = 1;
        }
        else if (value == -2){
            ldata = 2;
        }
        else if (value == -1){
            ldata = 3;
        }
        else if (value == 0){
            ldata = 4;
        }
        else if (value == 1){
            ldata = 5;
        }
        else if (value == 2){
            ldata = 6;
        }
        else {
            assert(false);
        }
        data = ldata | (data & ~7);
        return value;
    }

    float high() const @property
    {
        auto hdata = data >> 3;
        if (hdata == 1){
            return float.infinity;
        }
        else if (hdata == 2){
            return -2;
        }
        else if (hdata == 3){
            return -1;
        }
        else if (hdata == 4){
            return 0;
        }
        else if (hdata == 5){
            return 1;
        }
        else if (hdata == 6){
            return 2;
        }
        else {
            return float.nan;
        }
    }

    float high(float value) @property
    {
        ubyte hdata;
        if (value == float.infinity){
            hdata = 1;
        }
        else if (value == -2){
            hdata = 2;
        }
        else if (value == -1){
            hdata = 3;
        }
        else if (value == 0){
            hdata = 4;
        }
        else if (value == 1){
            hdata = 5;
        }
        else if (value == 2){
            hdata = 6;
        }
        else {
            assert(false);
        }
        data = data & 7 | cast(ubyte)(hdata << 3);
        return value;
    }

    float low_distance() const @property
    {
        if (_low_distance == ushort.max){
            return float.infinity;
        }
        return _low_distance;
    }

    float low_distance(float value) @property
    {
        if (value == float.infinity){
            _low_distance = ushort.max;
            return value;
        }
        assert(value >= 0 && value < ushort.max);
        _low_distance = to!ushort(value);
        return value;
    }

    float high_distance() const @property
    {
        if (_high_distance == ushort.max){
            return float.infinity;
        }
        return _high_distance;
    }

    float high_distance(float value) @property
    {
        if (value == float.infinity){
            _high_distance = ushort.max;
            return value;
        }
        assert(value >= 0 && value < ushort.max);
        _high_distance = to!ushort(value);
        return value;
    }

    string toString()
    {
        return format("ChessNodeValue(%s, %s, %s, %s)", low, high, low_distance, high_distance);
    }
}

/*
    CanonicalChessState s;
    auto type = EndgameType(0, 0, 1, 0, 1, 0, 0, 0, 0, 0);
    //writeln(type);

    NodeValue[][EndgameType] tables;
    size_t[EndgameType] valid;

    foreach (subtype; type.subtypes.byKey){
        writeln(subtype);
        writeln(subtype.size);
        tables[subtype] = [];
        tables[subtype].length = subtype.size;
        valid[subtype] = 0;
    }

    foreach (subtype, table; tables){
        foreach(e; 0..table.length){
            if (CanonicalChessState.from_endgame_state(e, subtype, s)){
                size_t ce = s.endgame_state(subtype);
                table[ce] = NodeValue(-float.infinity, float.infinity, float.infinity, float.infinity);
                valid[subtype] += 1;
            }
        }
    }

    writeln(valid);

    size_t i = 0;
    bool changed = true;
    while (changed) {
        i += 1;
        writeln("Iteration ", i);
        changed = false;
        foreach (subtype, table; tables){
            foreach(e; 0..table.length){
                auto v = table[e];
                if (v.initialized){
                    CanonicalChessState.from_endgame_state(e, subtype, s);
                    float score;
                    auto children = s.children(score);
                    float low = -float.infinity;
                    float high = -float.infinity;
                    float low_distance = float.infinity;
                    float high_distance = -float.infinity;
                    if (children.length){
                        foreach(child; children){
                            EndgameType ct;
                            auto ce = child.endgame_state(ct);
                            auto child_v = tables[ct][ce];
                            if (-child_v.high > low){
                                low = -child_v.high;
                                low_distance = child_v.high_distance;
                            }
                            else if (-child_v.high == low && child_v.high_distance < low_distance){
                                low_distance = child_v.high_distance;
                            }
                            if (-child_v.low > high){
                                high = -child_v.low;
                                high_distance = child_v.low_distance;
                            }
                            else if (-child_v.low == high && child_v.low_distance > high_distance){
                                high_distance = child_v.low_distance;
                            }
                        }
                        low_distance += 1;
                        high_distance += 1;
                    }
                    else {
                        low = high = score;
                        low_distance = high_distance = 0;
                    }
                    //writeln(low, high, low_distance, high_distance);
                    auto new_v = NodeValue(low, high, low_distance, high_distance);
                    if (new_v != v){
                        changed = true;
                    }
                    table[e] = new_v;
                }
            }
        }
    }


    float max_dist = 0;
    foreach(e; 0..tables[type].length){
        auto v = tables[type][e];
        if (v.initialized){
            if (v.low == 2 && v.low_distance > max_dist){
                max_dist = v.low_distance;
                CanonicalChessState.from_endgame_state(e, type, s);
                writeln(s);
                writeln(max_dist);
            }
        }
    }
*/


unittest
{
    Transposition[CanonicalChessState] ts;

    auto s = CanonicalChessState(
        PseudoChessState(
            RANK1 & EFILE,
            0,
            0,
            0,
            RANK5 & HFILE,
            0,
            RANK1 & (EFILE | HFILE),
            0
        )
    );

    auto n = new GameNode!(ChessMove, CanonicalChessState)(s);

    n.calculate_minimax_values(&ts);

    foreach (k, t; ts){
        auto state = k.state;
        if (state.player & state.rooks){
            assert(t.low_value == 1);
        }
    }
}

unittest
{
    Transposition[CanonicalChessState] ts;

    auto s = CanonicalChessState(
        PseudoChessState(
            RANK1 & EFILE,
            0,
            0,
            0,
            0,
            RANK5 & HFILE,
            RANK1 & (EFILE | HFILE),
            0
        )
    );

    auto n = new GameNode!(ChessMove, CanonicalChessState)(s);

    n.calculate_minimax_values(&ts);

    foreach (k, t; ts){
        auto state = k.state;
        if (state.player & state.queens){
            assert(t.low_value == 1);
        }
    }
}