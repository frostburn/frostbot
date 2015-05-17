module tsumego;

import std.stdio;

import board8;
import state;
import bounded_state;

// Cho Chikun's encyclopedia of life and death
// adapted version

// Intermediate problems

unittest
{
    // Problem 1
    BoundedState8[CanonicalState8] empty;
    auto state_pool = &empty;
    auto opponent = rectangle8(5, 1).south;
    auto space = rectangle8(7, 2) | Board8(7, 0) | Board8(0, 2);
    auto playing_area = rectangle8(8, 4);
    auto player = playing_area & ~space;
    auto s = State8(playing_area);
    s.player = player;
    s.player_unconditional = player;
    s.opponent = opponent;
    auto bs = new BoundedState8(CanonicalState8(s), state_pool);

    while(bs.expand){
    }
    writeln("Problem 1");
    writeln(s);
    writeln(bs);
    assert(bs.low_lower_bound == playing_area.popcount);
}