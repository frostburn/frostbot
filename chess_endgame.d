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

    this(int player, int opponent, bool dummy)
    {
        this.player = player;
        this.opponent = opponent;
    }

    this(ulong player, ulong opponent)
    {
        this.player = bitScanForward(player);
        this.opponent = bitScanForward(opponent);
    }

    static size_t size()
    {
        return KINGS_POSITION_TABLE.length;
    }

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
        auto indices = KINGS_POSITION_TABLE[index];
        return KingsPosition(indices[0], indices[1], true);
    }

    void get_boards(out ulong player_king, out ulong opponent_king) const
    {
        player_king = 1UL << player;
        opponent_king = 1UL << opponent;
    }

    size_t piece_index(int index)
    {
        auto ckp = from_index(this.index);
        auto transformed_index = _transform(index, this, ckp);
        return _piece_index(transformed_index, ckp.player, ckp.opponent);
    }

    size_t from_piece_index(size_t piece_index)
    {
        return _from_piece_index(piece_index, player, opponent);
    }

    string toString()
    {
        return format("KingsPosition(%d, %d, true)", player, opponent);
    }
}


size_t _piece_index(size_t index, size_t player, size_t opponent)
{
    if (index < player){
        if (index < opponent){
            return index;
        }
        return index - 1;
    }
    else if (index < opponent){
        return index - 1;
    }
    return index - 2;
}

size_t _from_piece_index(size_t index, size_t player, size_t opponent)
{
    if (index >= player){
        index += 1;
        if (index >= opponent){
            return index + 1;
        }
        return index;
    }
    else if (index >= opponent){
        index += 1;
        if (index >= player){
            return index + 1;
        }
        return index;
    }
    return index;
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

    // The extra check is for E8 that took priority in the representation.
    if (canonical.opponent == 4){
        int ox = original.opponent & 7;
        int oy = original.opponent >> 3;

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
            iy = 7 - iy;
        }
        return ix | (iy << 3);
    }

    // Depends on the specific choice of canonical representation.
    if (cpx == cpy){
        // Mirror symmetries determined by player.
        int ox = original.opponent & 7;
        if (px != cpx){
            ox = 7 - ox;
            ix = 7 - ix;
        }
        if (py != cpy){
            iy = 7 - iy;
        }
        // Flip symmetry determined by opponent.
        if (ox != cox){
            return iy | (ix << 3);
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
    int[][] kings_position_table;
    kings_position_table.length = 462;
    size_t legal_index = 0;

    enum collect_legal_representative = "
        auto c = canonical_index(player_x, player_y, opponent_x, opponent_y);
        if (c !in seen){
            if (legal(player_x, player_y, opponent_x, opponent_y)){
                canonical_table[c] = legal_index;
                kings_position_table[legal_index] = [player_index, opponent_index];
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
        static immutable int[][] KINGS_POSITION_TABLE = %s;
        static immutable size_t[][] KINGS_INDEX_TABLE = %s;
    ".format(kings_position_table, kings_index_table);
}

struct EndgameType
{
    int p_pawns;
    int o_pawns;
    int p_knights;
    int o_knights;
    int p_bishops;
    int o_bishops;
    int p_rooks;
    int o_rooks;
    int p_queens;
    int o_queens;

    enum MEMBERS = "[p_pawns, o_pawns, p_knights, o_knights, p_bishops, o_bishops, p_rooks, o_rooks, p_queens, o_queens]";

    this(int p_pawns, int o_pawns, int p_knights, int o_knights, int p_bishops, int o_bishops, int p_rooks, int o_rooks, int p_queens, int o_queens)
    {
        this.p_pawns = p_pawns;
        this.o_pawns = o_pawns;
        this.p_knights = p_knights;
        this.o_knights = o_knights;
        this.p_bishops = p_bishops;
        this.o_bishops = o_bishops;
        this.p_rooks = p_rooks;
        this.o_rooks = o_rooks;
        this.p_queens = p_queens;
        this.o_queens = o_queens;
    }

    this(int[] members)
    {
        p_pawns = members[0];
        o_pawns = members[1];
        p_knights = members[2];
        o_knights = members[3];
        p_bishops = members[4];
        o_bishops = members[5];
        p_rooks = members[6];
        o_rooks = members[7];
        p_queens = members[8];
        o_queens = members[9];
    }

    hash_t toHash() const nothrow @safe
    {
        static assert(hash_t.sizeof > 4);
        hash_t result = 0;
        foreach (member; mixin(MEMBERS)){
            result = 16 * result + member;
        }
        return result;
    }

    bool opEquals(in EndgameType rhs) const nothrow @safe
    {
        return toHash == rhs.toHash;
    }

    size_t size()
    {
        size_t result;
        if (p_pawns || o_pawns){
            result = 64 * 64;
            foreach (i, member; mixin(MEMBERS)){
                if (i == 0){
                    result *= 48 ^^ member;
                }
                else if (i == 1){
                    result *= 56 ^^ member;
                }
                else if (i == 6 || i == 7){
                    result *= 64 ^^ member;
                }
                else {
                    result *= 62 ^^ member;
                }
            }
        }
        else {
            result = KingsPosition.size;
            foreach (i, member; mixin(MEMBERS)){
                if (i == 6 || i == 7){
                    result *= 64 ^^ member;
                }
                else {
                    result *= 62 ^^ member;
                }
            }
        }
        return result;
    }

    EndgameType pair()
    {
        return EndgameType(o_pawns, p_pawns, o_knights, p_knights, o_bishops, p_bishops, o_rooks, p_rooks, o_queens, p_queens);
    }

    bool[EndgameType] _subtypes()
    {
        bool[EndgameType] result;
        int[] members = mixin(MEMBERS);
        foreach (i, member; members){
            if (member > 0){
                int[] submembers;
                foreach (j, submember; members){
                    if (i == j){
                        submembers ~= submember - 1;
                    }
                    else {
                        submembers ~= submember;
                    }
                }
                auto subtype = EndgameType(submembers);
                foreach (st; subtype._subtypes.byKey){
                    result[st] = true;
                }
                // Pawn promotions
                if (i <= 1){
                    foreach (k; 2..10){
                        if (k % 2 != i){
                            continue;
                        }
                        submembers.length = 0;
                        foreach (j, submember; members){
                            if (i == j){
                                submembers ~= submember - 1;
                            }
                            else if (k == j){
                                submembers ~= submember + 1;
                            }
                            else {
                                submembers ~= submember;
                            }
                        }
                        subtype = EndgameType(submembers);
                        foreach (st; subtype._subtypes.byKey){
                            result[st] = true;
                        }
                    }
                }
            }
        }
        result[this] = true;
        result[pair] = true;
        return result;
    }

    EndgameType[] subtypes()
    {
        EndgameType[] result;
        foreach (subtype; _subtypes.byKey){
            result ~= subtype;
        }
        return result;
    }

    string toString()
    {
        string r = "k";
        foreach (i; 0..p_pawns){
            r ~= "p";
        }
        foreach (i; 0..p_knights){
            r ~= "n";
        }
        foreach (i; 0..p_bishops){
            r ~= "b";
        }
        foreach (i; 0..p_rooks){
            r ~= "r";
        }
        foreach (i; 0..p_queens){
            r ~= "q";
        }
        r ~= "_k";
        foreach (i; 0..o_pawns){
            r ~= "p";
        }
        foreach (i; 0..o_knights){
            r ~= "n";
        }
        foreach (i; 0..o_bishops){
            r ~= "b";
        }
        foreach (i; 0..o_rooks){
            r ~= "r";
        }
        foreach (i; 0..o_queens){
            r ~= "q";
        }
        return r;
    }

    this(string s)
    {
        auto temp = split(s, '_');
        auto player = temp[0];
        auto opponent = temp[1];
        this(
            cast(int)countchars(player, "p"), cast(int)countchars(opponent, "p"),
            cast(int)countchars(player, "n"), cast(int)countchars(opponent, "n"),
            cast(int)countchars(player, "b"), cast(int)countchars(opponent, "b"),
            cast(int)countchars(player, "r"), cast(int)countchars(opponent, "r"),
            cast(int)countchars(player, "q"), cast(int)countchars(opponent, "q")
        );
    }
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
    foreach (p; 0..64){
        foreach (o; 0..64){
            if (legal(p & 7, p >> 3, o & 7, o >> 3)){
                auto kp = KingsPosition(p, o, true);
                auto ckp = KingsPosition.from_index(kp.index);
                auto tp = _transform(p, kp, ckp);
                auto to = _transform(o, kp, ckp);
                if (tp != ckp.player || to != ckp.opponent){
                    ulong k1, k2;
                    kp.get_boards(k1, k2);
                    writeln(on_board(k1, k2));
                    ckp.get_boards(k1, k2);
                    writeln(on_board(k1, k2));
                    writeln(on_board(1UL << tp, 1UL << to));
                    writeln;
                }
                assert(tp == ckp.player && to == ckp.opponent);
            }
        }
    }
}

unittest
{
    foreach (p; 0..64){
        foreach (o; 0..64){
            if (legal(p & 7, p >> 3, o & 7, o >> 3)){
                auto kp = KingsPosition(p, o, true);
                auto ckp = KingsPosition.from_index(kp.index);
                auto tp = _transform(p, kp, ckp);
                auto to = _transform(o, kp, ckp);
                assert(tp == ckp.player && to == ckp.opponent);
                foreach (n; 0..64){
                    if (n != p && n != o){
                        auto i = kp.piece_index(1UL << n);
                        auto n1 = ckp.from_piece_index(i);
                        ulong k1, k2;
                        ckp.get_boards(k1, k2);
                        auto s = PseudoChessState((1UL << p) | (1UL << n), 0, 1UL << n, 0, 0, 0, (1UL << p) | (1UL << o), 0);
                        auto cs = PseudoChessState(k1 | n1, 0, n1, 0, 0, 0, k1 | k2, 0);
                        if (CanonicalChessState(s) != CanonicalChessState(cs)){
                            writeln(_transform(o, kp, ckp));
                            writeln(_transform(n, kp, ckp));
                            writeln(s);
                            writeln(cs);
                        }
                        assert(CanonicalChessState(s) == CanonicalChessState(cs));
                    }
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