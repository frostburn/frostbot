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
    writeln("Problem 1");
    auto local_transpositions = &loc_trans;

    auto opponent = rectangle8(5, 1).south;
    auto space = rectangle8(7, 2) | Board8(7, 0) | Board8(0, 2);
    auto playing_area = rectangle8(8, 3);
    auto player = playing_area & ~space;
    auto s = State8(playing_area);
    s.player = player;
    s.player_unconditional = player;
    s.opponent = opponent;
    auto m = new HLManager8(CanonicalState8(s), local_transpositions);

    while(m.expand){
    }
    writeln(m.low_solution);
    writeln(m.node_pool.length, " nodes explored");
    assert(m.root.low == playing_area.popcount);
}

unittest
{
    writeln("Problem 2");
    auto local_transpositions = &loc_trans;

    auto opponent = rectangle8(6, 1).south | Board8(6, 0);
    auto space = rectangle8(6, 2) | Board8(6, 0) | Board8(7, 0) | Board8(0, 2);
    auto playing_area = rectangle8(8, 3);
    auto player = playing_area & ~space;
    auto s = State8(playing_area);
    s.player = player | Board8(1, 0);
    s.player_unconditional = player;
    s.opponent = opponent;
    auto m = new HLManager8(CanonicalState8(s), local_transpositions);

    while(m.expand){
    }
    writeln(m.low_solution);
    writeln(m.node_pool.length, " nodes explored");
    assert(m.root.low == playing_area.popcount);
}


unittest
{
    writeln("Problem 13");
    auto local_transpositions = &loc_trans;

    auto s = State8(rectangle8(7, 5));
    s.player = rectangle8(4, 1).south.east | Board8(1, 2);
    s.opponent = rectangle8(7, 5) ^ (rectangle8(7, 1) | rectangle8(5, 1).south | rectangle8(1, 5) | Board8(1, 2));
    s.opponent_unconditional = s.opponent;

    auto m = new HLManager8(CanonicalState8(s), local_transpositions);

    while(m.expand){
    }
    writeln(m.low_solution);
    writeln(m.node_pool.length, " nodes explored");
    assert(m.root.low == -11);
    assert(m.root.high == -11);
}


unittest
{
    writeln("Problem 464");;
    auto local_transpositions = &loc_trans;

    auto opponent = Board8(3, 0) | Board8(4, 1) | Board8(5, 1) | Board8(5, 2) | rectangle8(3, 1).south(2).east | Board8(0, 3);
    auto playing_area = rectangle8(7, 5);
    auto player = (rectangle8(6, 4) ^ rectangle8(5, 2)).south.east | Board8(4, 2);
    auto s = State8(playing_area);
    s.player = player | Board8(1, 0) | Board8(5, 0);
    s.player_unconditional = player;
    s.opponent = opponent;
    auto m = new HLManager8(CanonicalState8(s), local_transpositions);

    while(m.expand){
    }
    writeln(m.low_solution);
    writeln(m.node_pool.length, " nodes explored");
    assert(m.root.low == playing_area.popcount);
}
