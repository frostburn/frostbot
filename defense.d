module defense;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;
import std.typecons;

import utils;
import polyomino;
import board8;
import eyeshape;
import state;
import defense_state;
import defense_search_state;


enum Status {unknown, dead, killable, resurrectable, contested, retainable, defendable, secure}


struct DefenseResult(T)
{
    Status status = Status.unknown;
    T player_useless;
    T opponent_useless;

    this(Status status)
    {
        this.status = status;
    }

    this(Status status, T player_useless, T opponent_useless)
    {
        this.status = status;
        this.player_useless = player_useless;
        this.opponent_useless = opponent_useless;
    }
}

alias DefenseResult8 = DefenseResult!Board8;



DefenseState!T[] extract_player_eyespaces(T, S)(S state, T player_secure, T opponent_secure)
{
    DefenseState!T[] result;

    T player_edges;
    foreach (player_chain; state.player.chains){
        if (player_chain & opponent_secure){
            continue;
        }
        auto chain_size = player_chain.popcount;
        auto number_of_liberties = state.chain_liberties!"player"(player_chain);
        if (chain_size > 1 && number_of_liberties > 1){
            player_edges |= player_chain;
        }
    }

    T secure = player_secure | opponent_secure;

    // TODO: Check region pairs too.
    foreach (region; (state.playing_area & ~player_edges).chains){
        if (!(region & ~secure)){
            continue;
        }
        if (region.popcount <= 2){
            continue;
        }
        if (state.ko & region){
            continue;
        }
        T blob = region.blob(state.playing_area);
        T player_target = blob;
        player_target.flood_into(player_edges);
        T outside_liberties = player_target.liberties(state.playing_area & ~region);

        auto player_target_chains = player_target.chains;
        T[T] chains_per_liberty;
        foreach (target_chain; player_target_chains){
            T halo = target_chain.liberties(state.playing_area) & outside_liberties;
            foreach (halo_piece; halo.pieces){
                if (halo_piece in chains_per_liberty){
                    chains_per_liberty[halo_piece] |= target_chain;
                }
                else{
                    chains_per_liberty[halo_piece] = target_chain;
                }
            }
        }
        int[T] liberties_per_chain;
        foreach (chain; chains_per_liberty){
            if (chain in liberties_per_chain){
                liberties_per_chain[chain] += 1;
            }
            else{
                liberties_per_chain[chain] = 1;
            }
        }

        TargetChain!T[] player_targets;
        foreach (chain, liberties; liberties_per_chain){
            player_targets ~= TargetChain!T(chain, liberties);
        }

        auto playing_area = blob | player_target | secure;
        auto defense_state = DefenseState!T(
            state.player & playing_area,
            state.opponent & playing_area,
            playing_area,
            T(),
            player_secure,
            opponent_secure,
            player_target,
            T(),
            player_targets,
            [],
            true,
            0,
            float.infinity
        );
        result ~= defense_state;
    }
    return result;
}


void extract_eyespaces(T, S)(S state, T player_secure, T opponent_secure, out DefenseState!T[] player_eyespaces, out DefenseState!T[] opponent_eyespaces)
{
    player_eyespaces = extract_player_eyespaces!(T, S)(state, player_secure, opponent_secure);
    state.swap_turns;
    opponent_eyespaces = extract_player_eyespaces!(T, S)(state, opponent_secure, player_secure);
}

/*
    string return_winged_defense_result(string number)
    {
        return "
            auto result = DefenseResult!T(Status.contested);
            if (defense_state.player_outside_liberties & ~defense_state.player){
                result.player_useless = result.opponent_useless = " ~ number ~ "_space.wings;
            }
            return result;
        ";
    }


    // TODO: Create asserts with naive shape recognition.
    // Static analysis for small contiguous spaces.
    if (space.euler == 1){
        // Small spaces cannot be divided into two eyes.
        if (space_size <= 2){
            // TODO: Analyze if the group is part of a killing shape.
            //       If not, it's pointless to play in while outside liberties remain.
            return DefenseResult!T(Status.dead);
        }

        // Three spaces can always be killed by playing in the middle.
        if (space_size == 3){
            // It's pointless to play anywhere exept in the middle.
            // TODO: Prove this.

            auto three_space = get_three_space!T(space);

            if (defense_state.player & three_space.middle){
                return DefenseResult!T(Status.dead);
            }
            else{
                mixin(return_winged_defense_result("three"));
            }
        }

        if (space_size == 4){
            auto four_space = get_four_space!T(space);

            if (four_space.shape == FourShape.farmers_hat){
                if (defense_state.player & four_space.middle){
                    return DefenseResult!T(Status.dead);
                }
                else{
                    mixin(return_winged_defense_result("four"));
                }
            }
            else if (four_space.shape == FourShape.straight_four){
                auto number_of_attacking_stones = (defense_state.player & four_space.middle).popcount;
                if (number_of_attacking_stones == 2){
                    return DefenseResult!T(Status.dead);
                }
                else if (number_of_attacking_stones == 1){
                    mixin(return_winged_defense_result("four"));
                }
                else{
                    return DefenseResult!T(Status.defendable);
                }
            }
            else if (four_space.shape == FourShape.bent_four){
                auto number_of_attacking_stones = (defense_state.player & four_space.middle).popcount;
                if (number_of_attacking_stones == 2){
                    return DefenseResult!T(Status.dead);
                }
                else if (number_of_attacking_stones == 1){
                    mixin(return_winged_defense_result("four"));
                }
                // Bent four in the corner needs to fall through.
            }
            else if (four_space.shape == FourShape.square_four){
                if (defense_state.opponent & space){
                    auto smaller_space = space & ~defense_state.opponent;
                    if (smaller_space.popcount == 3){
                        auto three_space = get_three_space!T(smaller_space);

                        if (defense_state.player & three_space.middle){
                            return DefenseResult!T(Status.dead);
                        }
                        else{
                            mixin(return_winged_defense_result("three"));
                        }
                    }
                }
                else{
                    return DefenseResult!T(Status.killable);
                }
            }
            else if (four_space.shape == FourShape.twisted_four){
                auto number_of_attacking_stones = (defense_state.player & four_space.middle).popcount;
                if (number_of_attacking_stones == 2){
                    return DefenseResult!T(Status.dead);
                }
                else if (number_of_attacking_stones == 1){
                    mixin(return_winged_defense_result("four"));
                }
                // TODO: Consider static defendability analysis
            }
        }
    }

*/

enum MAX_SPACE_SIZE = 7;
enum MAX_OUTSIDE_LIBERTIES = 4;

DefenseResult!T calculate_status(T)(DefenseState!T defense_state, Transposition[DefenseState!T] *defense_transposition_table)
in
{
    assert(!defense_state.opponent_target);
    assert(!defense_state.opponent_immortal);
    assert(defense_state.black_to_play);
}
body
{
    debug(calculate_status) {
        writeln("Calculating status for:");
        writeln(defense_state);
    }
    if (!defense_state.player_target){
        return DefenseResult!T(Status.unknown);
    }

    if (defense_state.target_in_atari!"player"){
        return DefenseResult!T(Status.killable);
    }

    auto space = defense_state.playing_area & ~(defense_state.player_target | defense_state.player_immortal);
    auto space_size = space.popcount;

    if (space_size > MAX_SPACE_SIZE){
        return DefenseResult!T(Status.unknown);
    }

    float max_score = defense_state.playing_area.popcount;
    DefenseSearchState!(T, DefenseState!T) defense_search_state;
    T[] moves;

    if (defense_state.player_outside_liberties > MAX_OUTSIDE_LIBERTIES){
        // Let the attacker go first, remove the outside liberties and press the attack.
        defense_state.swap_turns;
        defense_state.black_to_play = true;
        defense_state.ko_threats = float.infinity;
        foreach (ref target; defense_state.opponent_targets){
            target.outside_liberties = 0;
        }
        defense_search_state = new DefenseSearchState!(T, DefenseState!T)(defense_state, 0, defense_transposition_table);
        defense_search_state.calculate_minimax_value;
        if (defense_search_state.upper_bound > -max_score){
            return DefenseResult!T(Status.unknown);
        }

        // Let the attacker go twice in a row for the ultimate invasion.
        foreach (child_state; defense_state.children_and_moves(moves)){
            child_state.swap_turns;
            assert(child_state.black_to_play);
            assert(child_state.ko_threats == float.infinity);
            defense_search_state = new DefenseSearchState!(T, DefenseState!T)(child_state, 0, defense_transposition_table);
            defense_search_state.calculate_minimax_value;
            if (defense_search_state.upper_bound > -max_score){
                return DefenseResult!T(Status.defendable);
            }
        }

        // That's one tough cookie right here.
        return DefenseResult!T(Status.secure);
    }
    else{
        // Make everything favor the defender to see if she can live in the first place with two moves in a row.
        defense_state.ko_threats = float.infinity;
        bool all_children_dead = true;
        foreach (child_state; defense_state.children_and_moves(moves)){
            if (!child_state.passes){
                child_state.swap_turns;
                assert(child_state.black_to_play);
                assert(child_state.ko_threats == float.infinity);
                defense_search_state = new DefenseSearchState!(T, DefenseState!T)(child_state, 0, defense_transposition_table);
                defense_search_state.calculate_minimax_value;
                if (defense_search_state.upper_bound > -float.infinity){
                    all_children_dead = false;
                    break;
                }
            }
        }
        if (all_children_dead){
            return DefenseResult!T(Status.dead);
        }

        // Now with only first move advantage.
        defense_search_state = new DefenseSearchState!(T, DefenseState!T)(defense_state, 0, defense_transposition_table);
        defense_search_state.calculate_minimax_value;
        if (defense_search_state.lower_bound < max_score){
            return DefenseResult!T(Status.killable);
        }

        // Make everything favor the attacker but keep the outside liberties.
        defense_state.swap_turns;
        defense_state.black_to_play = true;
        defense_state.ko_threats = float.infinity;
        defense_search_state = new DefenseSearchState!(T, DefenseState!T)(defense_state, 0, defense_transposition_table);
        defense_search_state.calculate_minimax_value;
        if (defense_search_state.upper_bound > -max_score){
            return DefenseResult!T(Status.contested);
        }

        // Remove the outside liberties to press the attack even further.
        foreach (ref target; defense_state.opponent_targets){
            target.outside_liberties = 0;
        }
        defense_search_state = new DefenseSearchState!(T, DefenseState!T)(defense_state, 0, defense_transposition_table);
        defense_search_state.calculate_minimax_value;
        if (defense_search_state.upper_bound > -max_score){
            return DefenseResult!T(Status.retainable);
        }

        // Let the attacker go twice in a row for the ultimate invasion.
        foreach (child_state; defense_state.children_and_moves(moves)){
            child_state.swap_turns;
            assert(child_state.black_to_play);
            assert(child_state.ko_threats == float.infinity);
            defense_search_state = new DefenseSearchState!(T, DefenseState!T)(child_state, 0, defense_transposition_table);
            defense_search_state.calculate_minimax_value;
            if (defense_search_state.upper_bound > -max_score){
                return DefenseResult!T(Status.defendable);
            }
        }

        // That's one tough cookie right here.
        return DefenseResult!T(Status.secure);
    }
}

alias calculate_status8 = calculate_status!Board8;


unittest
{
    Transposition[DefenseState8] *defense_transposition_table;

    auto space = rectangle8(3, 1).south.east;
    auto player = rectangle8(5, 3) & ~space;
    auto s = DefenseState8(space | player);
    s.player = player;
    s.player_target = player;
    auto result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.contested);

    s.player_outside_liberties = 2;
    result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.contested);

    s.opponent |= Board8(2, 1);
    result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.dead);

    space = rectangle8(4, 1).south.east;
    player = rectangle8(6, 3) & ~space;
    s = DefenseState8(space | player);
    s.player = player;
    s.player_target = player;
    assert(calculate_status8(s, defense_transposition_table).status == Status.defendable);

    s.playing_area &= ~Board8(0, 0) & ~Board8(0, 2);
    s.player &= ~Board8(0, 0) & ~Board8(0, 2);
    s.player_target = s.player;
    assert(calculate_status8(s, defense_transposition_table).status == Status.killable);


    space = rectangle8(5, 1).south.east;
    player = rectangle8(7, 3) & ~space;

    s.playing_area = space | player;
    s.player = player;
    s.player_target = player;
    assert(calculate_status8(s, defense_transposition_table).status == Status.secure);
}

unittest
{
    Transposition[DefenseState8] *defense_transposition_table;

    Board8 player_secure, opponent_secure;
    DefenseState8 s;
    s.player = rectangle8(5, 2) & ~rectangle8(4, 1);
    s.opponent = (rectangle8(6, 2) & ~rectangle8(5, 1).south).south(5);

    s.player |= Board8(1, 6);
    s.opponent |= Board8(1, 0);
    s.player |= Board8(3, 3) | Board8(4, 3) | Board8(6, 6);
    s.opponent |= Board8(5, 0) | Board8(6, 4);

    DefenseState8[] player_eyespaces;
    DefenseState8[] opponent_eyespaces;

    extract_eyespaces!(Board8, DefenseState8)(s, player_secure, opponent_secure, player_eyespaces, opponent_eyespaces);

    foreach (player_eyespace; player_eyespaces){
        calculate_status8(player_eyespace, defense_transposition_table);
    }

    bool opponent_has_a_defendable_group;
    foreach (opponent_eyespace; opponent_eyespaces){
        if (calculate_status(opponent_eyespace, defense_transposition_table).status == Status.defendable){
            opponent_has_a_defendable_group = true;
        }
    }
    assert(opponent_has_a_defendable_group);
}
