module defense;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import polyomino;
import board8;
import eyeshape;
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
        auto chain_size = player_chain.popcount;
        auto number_of_liberties = player_chain.liberties(state.playing_area & ~state.opponent).popcount;
        if (chain_size > 1 && number_of_liberties > 1){
            player_edges |= player_chain;
        }
    }

    // TODO: Check region pairs.
    foreach (region; (state.playing_area & ~player_edges).chains){
        if (region.popcount <= 2){
            continue;
        }
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

    // Check if target is in atari.
    foreach (target_chain; defense_state.opponent_target.chains){
        if (target_chain.liberties(defense_state.playing_area & ~defense_state.opponent).popcount <= 1){
            return Status.killable;
        }
    }

    auto space = defense_state.playing_area & ~defense_state.opponent_target & ~defense_state.player_outside_liberties;
    auto space_size = space.popcount;


    // TODO: Create asserts with naive shape recognition.
    // Static analysis for small contiguous spaces.
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

            auto three_space = get_three_space!T(space);

            if (defense_state.player & three_space.middle){
                return Status.dead;
            }
            else{
                if (defense_state.player_outside_liberties){
                    player_useless = opponent_useless = three_space.wings;
                }
                return Status.contested;
            }
        }

        if (space_size == 4){
            auto four_space = get_four_space!T(space);

            if (four_space.shape == FourShape.farmers_hat){
                if (defense_state.player & four_space.middle){
                    return Status.dead;
                }
                else{
                    if (defense_state.player_outside_liberties){
                        player_useless = opponent_useless = four_space.wings;
                    }
                    return Status.contested;
                }
            }
            else if (four_space.shape == FourShape.straight_four){
                auto number_of_attacking_stones = (defense_state.player & four_space.middle).popcount;
                if (number_of_attacking_stones == 2){
                    return Status.dead;
                }
                else if (number_of_attacking_stones == 1){
                    if (defense_state.player_outside_liberties){
                        player_useless = opponent_useless = four_space.wings;
                    }
                    return Status.contested;
                }
                else{
                    return Status.defendable;
                }
            }
            else if (four_space.shape == FourShape.bent_four){
                auto number_of_attacking_stones = (defense_state.player & four_space.middle).popcount;
                if (number_of_attacking_stones == 2){
                    return Status.dead;
                }
                else if (number_of_attacking_stones == 1){
                    if (defense_state.player_outside_liberties){
                        player_useless = opponent_useless = four_space.wings;
                    }
                    return Status.contested;
                }
                // Bent four in the corner needs to fall through.
            }
            else if (four_space.shape == FourShape.square_four){
                if (defense_state.opponent & space){
                    auto smaller_space = space & ~defense_state.opponent
                    if (smaller_space.popcount == 3){
                        auto three_space = get_three_space!T(smaller_space);

                        if (defense_state.player & three_space.middle){
                            return Status.dead;
                        }
                        else{
                            if (defense_state.player_outside_liberties){
                                player_useless = opponent_useless = three_space.wings;
                            }
                            return Status.contested;
                        }
                    }
                }
                else{
                    return Status.killable;
                }
            }
            else if (four_space.shape == FourShape.twisted_four){
                auto number_of_attacking_stones = (defense_state.player & four_space.middle).popcount;
                if (number_of_attacking_stones == 2){
                    return Status.dead;
                }
                else if (number_of_attacking_stones == 1){
                    if (defense_state.player_outside_liberties){
                        player_useless = opponent_useless = four_space.wings;
                    }
                    return Status.contested;
                }
            }
        }
    }

    if (space_size <= MAX_SPACE_SIZE){
        // Analyzing defendable territory. No outside forcing moves allowed.
        auto outside_liberties = defense_state.player_outside_liberties;
        defense_state.player_outside_liberties = T();
        defense_state.player &= ~outside_liberties;
        defense_state.playing_area &= ~outside_liberties;

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