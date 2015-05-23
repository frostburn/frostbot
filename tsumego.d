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

Transposition[LocalState8] loc_trans;

unittest
{
    // Problem 1
    HLNode8[CanonicalState8] empty;
    auto node_pool = &empty;
    auto local_transpositions = &loc_trans;

    auto opponent = rectangle8(5, 1).south;
    auto space = rectangle8(7, 2) | Board8(7, 0) | Board8(0, 2);
    auto playing_area = rectangle8(8, 3);
    auto player = playing_area & ~space;
    auto s = State8(playing_area);
    s.player = player;
    s.player_unconditional = player;
    s.opponent = opponent;
    auto n = new HLNode8(CanonicalState8(s), node_pool, local_transpositions);

    writeln("Problem 1");
    while(n.expand){
    }
    writeln(n.low_solution);
    writeln(node_pool.length, " nodes explored");
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

unittest
{
    // Problem 2
    HLNode8[CanonicalState8] empty;
    auto node_pool = &empty;
    auto local_transpositions = &loc_trans;

    auto opponent = rectangle8(6, 1).south | Board8(6, 0);
    auto space = rectangle8(6, 2) | Board8(6, 0) | Board8(7, 0) | Board8(0, 2);
    auto playing_area = rectangle8(8, 3);
    auto player = playing_area & ~space;
    auto s = State8(playing_area);
    s.player = player | Board8(1, 0);
    s.player_unconditional = player;
    s.opponent = opponent;
    auto n = new HLNode8(CanonicalState8(s), node_pool, local_transpositions);

    writeln("Problem 2");
    while(n.expand){
    }
    writeln(n.low_solution);
    writeln(node_pool.length, " nodes explored");
    assert(n.low == playing_area.popcount);
}
