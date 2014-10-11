module defense;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import polyomino;
import board8;
import defense_state;
import defense_search_state;


enum Status {dead, killable, unknown, defendable, secure}


enum MAX_SPACE_SIZE = 5;


Status calculate_status(T)(DefenseState!T defense_state)
in
{
    assert(!defense_state.player_target);
    assert(!defense_state.player_outside_liberties);
    assert(!defense_state.opponent_outside_liberties);  // TODO: Add support for outside liberties.
    assert(defense_state.black_to_play);
}
body
{
    if (!defense_state.opponent_target){
        return Status.unknown;
    }

    auto space_size = (defense_state.playing_area & ~defense_state.opponent_target).popcount;


    // Small spaces cannot be divided into two eyes.
    if (space_size <= 2){
        return Status.dead;
    }

    // Three spaces can always be killed by playing in the middle.
    if (space_size == 3){
        return Status.killable;
    }

    if (space_size <= MAX_SPACE_SIZE){
        // Check if target is in atari.
        foreach (target_chain; defense_state.opponent_target.chains){
            if (target_chain.liberties(defense_state.playing_area & ~defense_state.opponent).popcount <= 1){
                return Status.killable;
            }
        }

        defense_state.ko_threats = float.infinity;
        auto defense_search_state = new DefenseSearchState!(T, DefenseState!T)(defense_state);
        defense_search_state.calculate_minimax_value;

        if (defense_search_state.lower_bound == float.infinity && defense_search_state.upper_bound == float.infinity){
            return Status.killable;
        }

        if (defense_search_state.upper_bound < float.infinity && defense_search_state.lower_bound == defense_search_state.upper_bound){
            foreach (child_state; defense_state.children){
                child_state.swap_turns;
                assert(child_state.black_to_play);
                auto child_search_state = new DefenseSearchState!(T, DefenseState!T)(child_state);
                child_search_state.calculate_minimax_value;
                debug(calculate_status){
                    writeln("Child state:");
                    writeln(child_search_state);
                }
                if (child_search_state.upper_bound == float.infinity || child_search_state.lower_bound != child_search_state.upper_bound){
                    return Status.defendable;
                }
            }
            return Status.secure;
        }
    }

    return Status.unknown;
}


alias calculate_status8 = calculate_status!Board8;


unittest
{
    DefenseState8 s;
    auto space = rectangle8(3, 1).south.east;
    auto opponent = rectangle8(5, 3) & ~space;
    s.playing_area = space | opponent;
    s.opponent = opponent;
    s.opponent_target = opponent;
    assert(s.calculate_status8 == Status.killable);

    space = rectangle8(4, 1).south.east;
    opponent = rectangle8(6, 3) & ~space;
    s.playing_area = space | opponent;
    s.opponent = opponent;
    s.opponent_target = opponent;
    assert(s.calculate_status8 == Status.defendable);

    s.playing_area &= ~Board8(0, 0) & ~Board8(0, 2);
    s.opponent &= ~Board8(0, 0) & ~Board8(0, 2);
    s.opponent_target = s.opponent;
    assert(s.calculate_status8 == Status.killable);

    space = rectangle8(5, 1).south.east;
    opponent = rectangle8(7, 3) & ~space;

    s.playing_area = space | opponent;
    s.opponent = opponent;
    s.opponent_target = opponent;
    assert(s.calculate_status8 == Status.secure);
}