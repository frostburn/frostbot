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


enum Status {dead, killable, contested, unknown, defendable, secure}


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
        auto opponent_outside_liberties = player_target.liberties(state.playing_area & ~region);
        auto playing_area = blob | player_target | opponent_outside_liberties;
        auto defense_state = DefenseState!T(
            state.opponent & playing_area,
            state.player & playing_area,
            playing_area,
            T(),
            T(),
            player_target,
            opponent_outside_liberties,
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


Status calculate_status(T)(DefenseState!T defense_state, ref Status[DefenseState!T] transposition_table, out T player_useless, out T opponent_useless)
{
    if (defense_state !in transposition_table){
        auto status = calculate_status!T(defense_state, player_useless, opponent_useless);
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


Status calculate_status(T)(DefenseState!T defense_state, out T player_useless, out T opponent_useless)
in
{
    assert(!defense_state.player_target);
    assert(!defense_state.opponent_outside_liberties);
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

    auto space = defense_state.playing_area & ~defense_state.opponent_target & ~defense_state.player_outside_liberties;
    auto space_size = space.popcount;

    //Static analysis for small contiguous spaces.
    if (space.euler == 1){
        // Small spaces cannot be divided into two eyes.
        if (space_size <= 2){
            // TODO: Analyze if the group is part of a killing shape.
            //       If not, it's pointless to play in while outside liberties remain.
            return Status.dead;
        }

        // Three spaces can always be killed by playing in the middle.
        if (space_size == 3){
            // It's pointless to play anywhere exept in the middle.
            // TODO: Prove this.

            T temp = space & space.east;
            T middle = temp & temp.west;
            T wings;
            if (middle){  // Horizontal straight three.
                wings = middle.east | middle.west;
            }
            else{
                if (temp){  // Bent three.
                    if (space & temp.south){
                        middle = temp;
                        wings = middle.south | middle.west;
                    }
                    else if(space & temp.north){
                        middle = temp;
                        wings = middle.north | middle.west;
                    }
                    else{
                        middle = temp.west;
                        if (space & middle.north){
                            wings = middle.north | temp;
                        }
                        else{
                            wings = middle.south | temp;
                        }
                    }
                }
                else{  // Vertical straight three.
                    temp = space & space.north;
                    middle = temp & temp.south;
                    wings = middle.north | middle.south;
                }
            }
            if (defense_state.player & middle){
                return Status.dead;
            }
            else{
                if (defense_state.player_outside_liberties){
                    player_useless = wings;
                    opponent_useless = wings;
                }
                return Status.contested;
            }
        }
    }

    //if (farmers_hat || star_five){
        // TODO: It's pointless to play anywhere exept in the middle.
        // TODO: Prove this.
    //}

    if (space_size <= MAX_SPACE_SIZE){
        // Analyzing defendable territory. No outside forcing moves allowed.
        auto outside_liberties = defense_state.player_outside_liberties;
        defense_state.player_outside_liberties = T();
        defense_state.player &= ~outside_liberties;
        defense_state.playing_area &= ~outside_liberties;

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

Status calculate_status8(DefenseState8 defense_state,ref Status[DefenseState8] transposition_table, out Board8 player_useless, out Board8 opponent_useless)
{
    return calculate_status!Board8(defense_state, transposition_table, player_useless, opponent_useless);
}

Status calculate_status8(DefenseState8 defense_state, out Board8 player_useless, out Board8 opponent_useless)
{
    return calculate_status!Board8(defense_state, player_useless, opponent_useless);
}



unittest
{
    Board8 player_useless, opponent_useless;
    DefenseState8 s;
    s.ko_threats = float.infinity;
    auto space = rectangle8(3, 1).south.east;
    auto opponent = rectangle8(5, 3) & ~space;
    s.playing_area = space | opponent;
    s.opponent = opponent;
    s.opponent_target = opponent;
    assert(calculate_status8(s, player_useless, opponent_useless) == Status.contested);
    assert(!player_useless && !opponent_useless);

    s.playing_area |= Board8(0, 3);
    s.player_outside_liberties = Board8(0, 3);
    Board8 wings = Board8(1, 1) | Board8(3, 1);
    assert(calculate_status8(s, player_useless, opponent_useless) == Status.contested);
    assert(player_useless == wings);
    assert(opponent_useless == wings);

    s.player |= Board8(2, 1);
    assert(calculate_status8(s, player_useless, opponent_useless) == Status.dead);
    assert(!player_useless && !opponent_useless);

    space = rectangle8(4, 1).south.east;
    opponent = rectangle8(6, 3) & ~space;
    s = DefenseState8(space | opponent);
    s.ko_threats = float.infinity;
    s.opponent = opponent;
    s.opponent_target = opponent;
    assert(calculate_status8(s, player_useless, opponent_useless) == Status.defendable);

    s.playing_area &= ~Board8(0, 0) & ~Board8(0, 2);
    s.opponent &= ~Board8(0, 0) & ~Board8(0, 2);
    s.opponent_target = s.opponent;
    assert(calculate_status8(s, player_useless, opponent_useless) == Status.killable);

    space = rectangle8(5, 1).south.east;
    opponent = rectangle8(7, 3) & ~space;

    s.playing_area = space | opponent;
    s.opponent = opponent;
    s.opponent_target = opponent;
    assert(calculate_status8(s, player_useless, opponent_useless) == Status.secure);
}

unittest
{
    Board8 player_useless, opponent_useless;
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
        calculate_status8(player_eyespace, player_useless, opponent_useless);
    }

    bool opponent_has_a_defendable_group;
    foreach (opponent_eyespace; opponent_eyespaces){
        
        if (calculate_status(opponent_eyespace, player_useless, opponent_useless) == Status.defendable){
            opponent_has_a_defendable_group = true;
        }
    }
    assert(opponent_has_a_defendable_group);
}