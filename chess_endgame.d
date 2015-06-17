import std.stdio;
import std.string;
import std.conv;
import std.math;

import utils;
import chess;
import game_node;


// Canoninable legal configuration of kings
struct KingsPosition
{
    int player;
    int opponent;

    mixin(get_kings_index_tables);

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
        auto kp = KINGS_POSITION_TABLE[index];
        auto transformed_index = transform(bitScanForward(piece), this, kp);
        return _piece_index(transformed_index, kp);
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

int _transform(int index, KingsPosition original, KingsPosition canonical){
    int ix = index & 7;
    int iy = index >> 3;
    int px = original.player & 7;
    int py = original.player >> 3;
    int cpx = canonical.player & 7;
    int cpy = canonical.player >> 3;
    int cox = canonical.opponent & 7;
    int coy = canonical.opponent >> 3;
    int temp;

    // Depends on the specific choice of canonical representation.
    // The extra check is for E8 that took priority.
    if (cpx == cpy || canonical.opponent == 4){
        // Symmetry determined by the opponent and a few other factors.
        int ox = original.opponent & 7;
        int oy = original.opponent >> 3;

        // Ad hoc.
        if (px == cpx && py == cpy){
            if (ox != cox){
                return iy | (ix << 3);
            }
            return index;
        }

        if (ox != cox){
            ox = 7 - ox;
            ix = 7 - ix;
        }
        if (ox != cox){
            temp = ox;
            ox = oy;
            oy = temp;
            temp = ix;
            ix = iy;
            iy = temp;
        }
        if (ox != cox){
            ix = 7 - ix;
        }
        if (oy != coy){
            // Ad hoc.
            if (px == 7 - py && px == 7 - cpx){
                return iy | ((7 - ix) << 3);
            }
            iy = 7 - iy;
        }
        return ix | (iy << 3);
    }
    // Symmetry determined by the player.

    if (px != cpx){
        px = 7 - px;
        ix = 7 - ix;
    }
    if (px != cpx){
        temp = px;
        px = py;
        py = temp;
        temp = ix;
        ix = iy;
        iy = temp;
    }
    if (px != cpx){
        ix = 7 - ix;
    }
    if (py != cpy){
        iy = 7 - iy;
    }
    return ix | (iy << 3);
    /*
    int ix = index & 7;
    int iy = index >> 3;
    int ox = opponent & 7;
    int oy = opponent >> 3;
    int temp, minx, miny;

    if (ox < 4){
        minx = ox;
    }
    else {
        minx = 7 - ox;
    }
    if (oy < 4){
        miny = oy;
    }
    else{
        miny = 7 - oy;
    }
    bool flip = minx < miny;
    if (minx == miny){
        int px = player & 7;
        int py = player >> 3;
        if (oy < 4){
            if (ox < 4){
                flip = py > px;
            }
            else {
                flip = py > 7 - px;
            }
        }
        else {
            if (ox < 4){
                flip = 7 - py > px;
            }
            else {
                flip = py < px;
            }
        }
    }
    if (flip){
        temp = ox;
        ox = oy;
        oy = temp;
        temp = ix;
        ix = iy;
        iy = temp;
    }

    if (oy < 4){
        if (ox < 4){
            return ix | (iy << 3);
        }
        else {
            return (7 - ix) | (iy << 3);
        }
    }
    else {
        if (ox < 4){
            return ix | ((7 - iy) << 3);
        }
        else {
            return (7 - ix) | ((7 - iy) << 3);
        }
    }
    */
}

int canonical_index(int px, int py, int ox, int oy)
{
    int result = px + 8 * (py + 8 * (ox + 8 * oy));
    int temp;
    int tmp;
    enum compare_and_replace = "
        temp = px + 8 * (py + 8 * (ox + 8 * oy));
        if (temp < result){
            result = temp;
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
    return abs(px - ox) > 1 || abs(py - oy) > 1;
}


// Representation chosen so that E1 and E8 are preserved to make castling easier.
// Diagonally symmetric positions always have x = y and never x = 7 - y.
string get_kings_index_tables()
{
    bool[size_t] seen;
    size_t[] canonical_table;
    canonical_table.length = 64 * 64;
    canonical_table[] = 64 * 64;
    KingsPosition[] kings_position_table;
    kings_position_table.length = 462;
    size_t legal_index = 0;

    enum collect_legal_representative = "
        auto c = canonical_index(player_x, player_y, opponent_x, opponent_y);
        if (c !in seen){
            if (legal(player_x, player_y, opponent_x, opponent_y)){
                canonical_table[c] = legal_index;
                kings_position_table[legal_index] = KingsPosition(player_index, opponent_index);
                legal_index += 1;
            }
            seen[c] = true;
        }
    ";

    // E1
    foreach (opponent_x; 0..8){
        foreach (opponent_y; 0..8){
            auto player_x = 4;
            auto player_y = 7;
            auto player_index = player_x + player_y * 8;
            auto opponent_index = opponent_x + opponent_y * 8;
            mixin(collect_legal_representative);
        }
    }

    // E8
    foreach (player_x; 0..8){
        foreach (player_y; 0..8){
            auto player_index = player_x + player_y * 8;
            auto opponent_x = 4;
            auto opponent_y = 0;
            auto opponent_index = opponent_x + opponent_y * 8;
            mixin(collect_legal_representative);
        }
    }

    // Diagonally symmetric positions and a few others
    foreach (player_x; 0..8){
        auto player_y = player_x;
        auto player_index = player_x + player_y * 8;
        foreach (opponent_x; 0..8){
            foreach (opponent_y; 0..8){
                auto opponent_index = opponent_x + opponent_y * 8;
                mixin(collect_legal_representative);
            }
        }
    }

    // Everything else
    foreach (player_x; 0..8){
        foreach (player_y; 0..8){
            auto player_index = player_x + player_y * 8;
            foreach (opponent_x; 0..8){
                foreach (opponent_y; 0..8){
                    auto opponent_index = opponent_x + opponent_y * 8;
                    mixin(collect_legal_representative);
                }
            }
        }
    }

    if (!__ctfe){
        writeln(legal_index);
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
    foreach (player_x; 0..8){
        foreach (player_y; 0..8){
            auto player_index = player_x + player_y * 8;
            foreach (opponent_x; 0..8){
                foreach (opponent_y; 0..8){
                    auto opponent_index = opponent_x + opponent_y * 8;
                    auto c = canonical_index(player_x, player_y, opponent_x, opponent_y);
                    auto canonical_player_index = transform(player_index, player_index, opponent_index);
                    auto canonical_opponent_index = transform(opponent_index, player_index, opponent_index);
                    assert(c == canonical_player_index + 64 * canonical_opponent_index);
                }
            }
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