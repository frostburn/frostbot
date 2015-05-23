module tsumego;

import std.stdio;

import board8;
import state;
import game_node;
import local;
import hl_node;

// Cho Chikun's encyclopedia of life and death
// adapted version

// Intermediate problems

unittest
{
    // Problem 1
    HLNode8[CanonicalState8] empty;
    auto state_pool = &empty;
    Transposition[LocalState8] empty2;
    auto local_transpositions = &empty2;

    auto opponent = rectangle8(5, 1).south;
    auto space = rectangle8(7, 2) | Board8(7, 0) | Board8(0, 2);
    auto playing_area = rectangle8(8, 4);
    auto player = playing_area & ~space;
    auto s = State8(playing_area);
    s.player = player;
    s.player_unconditional = player;
    s.opponent = opponent;
    auto n = new HLNode8(CanonicalState8(s), state_pool, local_transpositions);

    writeln("Problem 1");
    writeln(s);
    while(n.expand){
    }
    writeln(n);
    writeln(state_pool.length);
    assert(n.low == playing_area.popcount);

    /*
    foreach (ls; (*local_transpositions).byKey){
        auto t = (*local_transpositions)[ls];
        writeln(ls);
        writeln(t);
        auto g = new GameNode!(Board8, LocalState8)(ls);
        g.calculate_minimax_values;
        writeln(g.low_value, ", ", g.high_value);
        assert(g.low_value == t.low_value);
        assert(g.high_value == t.high_value);
    }
    */
}