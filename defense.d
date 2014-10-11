module defense;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import polyomino;
import board8;
import state;
import defense_state;
import defense_search_state;


enum Status {dead, killable, unknown, defendable, secure}


enum MAX_SPACE_SIZE = 6;


DefenseState!T[] extract_player_eyespaces(T, S)(S state)
{
    DefenseState!T[] result;

    T player_edges;
    foreach (player_chain; state.player.chains){
        // TODO: Exclude certain chains of size two.
        if (player_chain.popcount > 1){
            player_edges |= player_chain;
        }
    }

    foreach (region; (state.playing_area & ~player_edges).chains){
        if (state.ko & region){
            continue;
        }
        auto blob = region.blob(state.playing_area);
        auto player_target = blob;
        player_target.flood_into(player_edges);
        auto playing_area = blob | player_target;
        auto defense_state = DefenseState!T(
            state.opponent & playing_area,
            state.player & playing_area,
            playing_area,
            T(),
            T(),
            player_target,
            T(),
            T(),
            true,
            0,
            float.infinity
        );
        result ~= defense_state;
    }
    return result;
}


void extract_eyespaces(T, S)(S state, out DefenseState!T[] player_eyespaces, out DefenseState!T[] opponent_eyespaces)
{
    player_eyespaces = extract_player_eyespaces!(T, S)(state);
    state.swap_turns;
    opponent_eyespaces = extract_player_eyespaces!(T, S)(state);
}


Status calculate_status(T)(DefenseState!T defense_state, ref Status[DefenseState!T] transposition_table)
{
    if (defense_state !in transposition_table){
        auto status = calculate_status!T(defense_state);
        transposition_table[defense_state] = status;
        debug(calculate_status_transpositions){
            if (status == Status.defendable){
                writeln("Saving status for:");
                writeln(defense_state);
                writeln(status);
                writeln;
            }
        }
        return status;
    }
    else{
        return transposition_table[defense_state];
    }
}


Status calculate_status(T)(DefenseState!T defense_state)
in
{
    assert(!defense_state.player_target);
    assert(!defense_state.player_outside_liberties);
    assert(!defense_state.opponent_outside_liberties);  // TODO: Add support for outside liberties.
    assert(defense_state.black_to_play);
    assert(defense_state.ko_threats == float.infinity);
}
body
{
    debug(calculate_status) {
        writeln("Calculating status for:");
        writeln(defense_state);
    }
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

        auto defense_search_state = new DefenseSearchState!(T, DefenseState!T)(defense_state);
        defense_search_state.calculate_minimax_value;

        if (defense_search_state.lower_bound == float.infinity && defense_search_state.upper_bound == float.infinity){
            return Status.killable;
        }

        int min_score = defense_state.playing_area.popcount;
        min_score = -min_score;
        if (defense_search_state.lower_bound > min_score){
            // Probably a seki.
            return Status.unknown;
        }
        if (defense_search_state.lower_bound == min_score && defense_search_state.upper_bound == min_score){
            foreach (child_state; defense_state.children){
                child_state.swap_turns;
                assert(child_state.black_to_play);
                auto child_search_state = new DefenseSearchState!(T, DefenseState!T)(child_state);
                child_search_state.calculate_minimax_value;
                debug(calculate_status){
                    writeln("Child state:");
                    writeln(child_search_state);
                }
                if (child_search_state.lower_bound > min_score){
                    return Status.defendable;
                }
            }
            return Status.secure;
        }
    }

    return Status.unknown;
}


// Hmmm?? No double specializations?
// alias calculate_status8 = calculate_status!Board8;

Status calculate_status8(DefenseState8 defense_state,ref Status[DefenseState8] transposition_table)
{
    return calculate_status!Board8(defense_state, transposition_table);
}

Status calculate_status8(DefenseState8 defense_state)
{
    return calculate_status!Board8(defense_state);
}



unittest
{
    DefenseState8 s;
    s.ko_threats = float.infinity;
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

unittest
{
    State8 s;
    s.player = rectangle8(5, 2) & ~rectangle8(4, 1);
    s.opponent = (rectangle8(6, 2) & ~rectangle8(5, 1).south).south(5);

    s.player |= Board8(1, 6);
    s.opponent |= Board8(1, 0);
    s.player |= Board8(3, 3) | Board8(4, 3) | Board8(6, 6);
    s.opponent |= Board8(5, 0) | Board8(6, 4);

    DefenseState8[] player_eyespaces;
    DefenseState8[] opponent_eyespaces;

    extract_eyespaces!(Board8, State8)(s, player_eyespaces, opponent_eyespaces);

    foreach (player_eyespace; player_eyespaces){
        player_eyespace.calculate_status8;
    }

    bool opponent_has_a_defendable_group;
    foreach (opponent_eyespace; opponent_eyespaces){
        
        if (opponent_eyespace.calculate_status8 == Status.defendable){
            opponent_has_a_defendable_group = true;
        }
    }
    assert(opponent_has_a_defendable_group);
}