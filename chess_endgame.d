import std.stdio;
import std.string;
import std.conv;

import chess;
import game_node;


struct NodeValue
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

    bool opEquals(in NodeValue rhs) const pure nothrow @nogc @safe
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
        return format("NodeValue(%s, %s, %s, %s)", low, high, low_distance, high_distance);
    }
}

/*
    NodeValue[] table;
    table.length = CanonicalChessState.endgame_size("knn_k");

    size_t valid = 0;
    foreach(e; 0..table.length){
        if (CanonicalChessState.from_endgame_state("knn_k", e, s)){
            size_t ce = s.endgame_state("knn_k");
            table[ce] = NodeValue(-float.infinity, float.infinity);
            if (s.diagonal.popcount == 4){
                valid += 1;
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
        foreach(e; 0..table.length){
            auto v = table[e];
            if (v.initialized && v.low != v.high){
                CanonicalChessState.from_endgame_state("knn_k", e, s);
                float score;
                auto children = s.children(score);
                float low = -float.infinity;
                float high = -float.infinity;
                if (children.length){
                    foreach(child; children){
                        auto child_v = table[child.endgame_state("knn_k")];
                        if (-child_v.high > low){
                            low = -child_v.high;
                        }
                        if (-child_v.low > high){
                            high = -child_v.low;
                        }
                    }
                }
                else {
                    low = high = score;
                }
                auto new_v = NodeValue(low, high);
                if (new_v != v){
                    changed = true;
                }
                table[e] = new_v;
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