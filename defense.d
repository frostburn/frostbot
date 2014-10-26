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
        auto number_of_liberties = state.player_chain_liberties(player_chain);
        if (chain_size > 1 && number_of_liberties > 1){
            player_edges |= player_chain;
        }
    }

    T secure = player_secure | opponent_secure;

    // TODO: Check region pairs too.
    auto regions = (state.playing_area & ~player_edges).chains;
    foreach (index, region1; regions){
        for (size_t i = index; i < regions.length; i++){
            auto region = region1 | regions[i];
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
    }
    return result;
}


void extract_eyespaces(T, S)(S state, T player_secure, T opponent_secure, out DefenseState!T[] player_eyespaces, out DefenseState!T[] opponent_eyespaces)
{
    player_eyespaces = extract_player_eyespaces!(T, S)(state, player_secure, opponent_secure);
    state.swap_turns;
    opponent_eyespaces = extract_player_eyespaces!(T, S)(state, opponent_secure, player_secure);
}


DefenseResult!T static_analysis(T)(DefenseState!T defense_state, T space, int space_size, out bool use_result)
{
    use_result = true;
    // TODO: Create asserts with naive shape recognition.
    // Static analysis for small contiguous spaces.
    if (space.true_euler == 1){
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

            if (defense_state.opponent & three_space.middle){
                return DefenseResult!T(Status.dead);
            }
            else{
                return DefenseResult!T(Status.contested, three_space.wings, three_space.wings);
            }
        }

        if (space_size == 4){
            auto four_space = get_four_space!T(space);

            if (four_space.shape == FourShape.farmers_hat){
                if (defense_state.opponent & four_space.middle){
                    return DefenseResult!T(Status.dead);
                }
                else{
                    return DefenseResult!T(Status.contested, four_space.wings, four_space.wings);
                }
            }
            else if (four_space.shape == FourShape.straight_four){
                auto number_of_attacking_stones = (defense_state.opponent & four_space.middle).popcount;
                if (number_of_attacking_stones == 2){
                    return DefenseResult!T(Status.dead);
                }
                else if (number_of_attacking_stones == 1){
                    return DefenseResult!T(Status.contested, four_space.wings, four_space.wings);
                }
                else{
                    return DefenseResult!T(Status.defendable, four_space.wings, four_space.wings);
                }
            }
            else if (four_space.shape == FourShape.bent_four){
                auto number_of_attacking_stones = (defense_state.opponent & four_space.middle).popcount;
                if (number_of_attacking_stones == 2){
                    return DefenseResult!T(Status.dead);
                }
            }
            else if (four_space.shape == FourShape.square_four){
                if (defense_state.opponent & space){
                    auto smaller_space = space & ~defense_state.opponent;
                    if (smaller_space.popcount == 3){
                        auto three_space = get_three_space!T(smaller_space);

                        if (defense_state.opponent & three_space.middle){
                            return DefenseResult!T(Status.dead);
                        }
                        else{
                            return DefenseResult!T(Status.contested, three_space.wings, three_space.wings);
                        }
                    }
                }
                else{
                    return DefenseResult!T(Status.killable);
                }
            }
            else if (four_space.shape == FourShape.twisted_four){
                auto number_of_attacking_stones = (defense_state.opponent & four_space.middle).popcount;
                if (number_of_attacking_stones == 2){
                    return DefenseResult!T(Status.dead);
                }
            }
        }
    }
    use_result = false;
    return DefenseResult!T(Status.unknown);
}

enum MAX_SPACE_SIZE = 8;
enum MAX_OUTSIDE_LIBERTIES = 5;

DefenseResult!T calculate_status(T)(DefenseState!T defense_state, Transposition[DefenseState!T] *defense_transposition_table)
in
{
    assert(!defense_state.opponent_target);
    //assert(!defense_state.opponent_immortal);
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

    if (space_size <= 4 && !defense_state.opponent_immortal){
        bool use_result = false;
        auto result = static_analysis!T(defense_state, space, space_size, use_result);
        if (use_result){
            return result;
        }
    }

    if (space_size > MAX_SPACE_SIZE){
        return DefenseResult!T(Status.unknown);
    }

    float max_score = defense_state.playing_area.popcount;
    DefenseSearchState!(T, CanonicalDefenseState!T) defense_search_state;
    T[] moves;
    T player_useless;
    T opponent_useless;

    if (defense_state.player_outside_liberties > MAX_OUTSIDE_LIBERTIES){
        // Let the attacker go first, remove the outside liberties and press the attack.
        defense_state.swap_turns;
        defense_state.black_to_play = true;
        defense_state.ko_threats = float.infinity;
        foreach (ref target; defense_state.opponent_targets){
            target.outside_liberties = 0;
        }
        defense_search_state = new DefenseSearchState!(T, CanonicalDefenseState!T)(defense_state, defense_transposition_table, false);
        defense_search_state.calculate_minimax_value;
        if (defense_search_state.upper_bound > -max_score){
            return DefenseResult!T(Status.unknown);
        }

        // Let the attacker go twice in a row for the ultimate invasion.
        foreach (child_state; defense_state.children_and_moves(moves)){
            child_state.swap_turns;
            assert(child_state.black_to_play);
            assert(child_state.ko_threats == float.infinity);
            defense_search_state = new DefenseSearchState!(T, CanonicalDefenseState!T)(child_state, defense_transposition_table, false);
            defense_search_state.calculate_minimax_value;
            if (defense_search_state.upper_bound > -max_score){
                return DefenseResult!T(Status.defendable);
            }
        }

        // That's one tough cookie right here.
        return DefenseResult!T(Status.secure);
    }
    else{
        //version(calculate_death){
            // Make everything favor the defender to see if she can live in the first place with two moves in a row.
            defense_state.ko_threats = float.infinity;
            bool all_children_dead = true;
            foreach (child_state; defense_state.children_and_moves(moves)){
                if (!child_state.passes){
                    child_state.swap_turns;
                    assert(child_state.black_to_play);
                    assert(child_state.ko_threats == float.infinity);
                    defense_search_state = new DefenseSearchState!(T, CanonicalDefenseState!T)(child_state, defense_transposition_table, false);
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
        //}

        // Now with only first move advantage.
        defense_state.ko_threats = float.infinity;
        bool is_killable = true;
        foreach (index, child_state; defense_state.children_and_moves(moves)){
            auto move = moves[index];
            child_state.black_to_play = true;
            defense_search_state = new DefenseSearchState!(T, CanonicalDefenseState!T)(child_state, defense_transposition_table, false);
            defense_search_state.calculate_minimax_value;
            if (defense_search_state.upper_bound > -max_score){
                player_useless |= move;
            }
            else{
                is_killable = false;
            }
        }
        if (is_killable){
            return DefenseResult!T(Status.killable);
        }

        // Make everything favor the attacker but keep the outside liberties.
        defense_state.swap_turns;
        defense_state.black_to_play = true;
        defense_state.ko_threats = float.infinity;
        bool is_contested = false;
        foreach (index, child_state; defense_state.children_and_moves(moves)){
            auto move = moves[index];
            child_state.black_to_play = true;
            defense_search_state = new DefenseSearchState!(T, CanonicalDefenseState!T)(child_state, defense_transposition_table, false);
            defense_search_state.calculate_minimax_value;
            if (defense_search_state.lower_bound < max_score){
                is_contested = true;
            }
            else{
                opponent_useless |= move;
            }
        }
        if (is_contested){
            return DefenseResult!T(Status.contested, player_useless, opponent_useless);
        }

        // Check for potential ko-threats.
        opponent_useless = T();
        foreach (index, child_state; defense_state.children_and_moves(moves)){
            if (!child_state.passes){
                auto move = moves[index];
                child_state.swap_turns;
                assert(child_state.black_to_play);
                assert(child_state.ko_threats == float.infinity);
                defense_search_state = new DefenseSearchState!(T, CanonicalDefenseState!T)(child_state, defense_transposition_table, false);
                defense_search_state.calculate_minimax_value;
                if (defense_search_state.upper_bound == -max_score){
                    opponent_useless |= move;
                }
            }
        }

        // Remove the outside liberties to press the attack even further.
        defense_state.opponent_outside_liberties = 0;
        defense_search_state = new DefenseSearchState!(T, CanonicalDefenseState!T)(defense_state, defense_transposition_table, false);
        defense_search_state.calculate_minimax_value;
        if (defense_search_state.upper_bound > -max_score){
            return DefenseResult!T(Status.retainable, player_useless, opponent_useless);
        }

        // Let the attacker go twice in a row for the ultimate invasion.
        bool is_defendable = false;
        opponent_useless = T();
        foreach (index, child_state; defense_state.children_and_moves(moves)){
            if (!child_state.passes){
                auto move = moves[index];
                child_state.swap_turns;
                assert(child_state.black_to_play);
                assert(child_state.ko_threats == float.infinity);
                defense_search_state = new DefenseSearchState!(T, CanonicalDefenseState!T)(child_state, defense_transposition_table, false);
                defense_search_state.calculate_minimax_value;
                if (defense_search_state.upper_bound > -max_score){
                    is_defendable = true;
                }
                else{
                    opponent_useless |= move;
                }
            }
        }
        if (is_defendable){
            return DefenseResult!T(Status.defendable, player_useless, opponent_useless);
        }

        // That's one tough cookie right here.
        return DefenseResult!T(Status.secure);
    }
}

alias calculate_status8 = calculate_status!Board8;


struct DefenseAnalysisResult(T)
{
    T player_secure;
    T opponent_secure;
    T player_retainable;
    T opponent_retainable;
    T player_useless;  // Instead of this just return the available moves.

    float lower_bound;
    float upper_bound;
    float score;
}

DefenseAnalysisResult!T analyze_state(T, C)(C state, T player_secure, T opponent_secure, Transposition[DefenseState!T] *defense_transposition_table)
{
    DefenseState!T[] player_eyespaces;
    DefenseState!T[] opponent_eyespaces;

    extract_eyespaces!(T, C)(state, player_secure, opponent_secure, player_eyespaces, opponent_eyespaces);

    T player_useless;

    T player_defendable;
    T opponent_defendable;
    T player_retainable;
    T opponent_retainable;

    static if (is (C == CanonicalDefenseState!T)){
        float size_limit = state.playing_area.popcount;
    }
    else{
        float size_limit = float.infinity;
    }

    DefenseResult!T[DefenseState!T] player_deferred;
    DefenseResult!T[DefenseState!T] opponent_deferred;

    string analyze_eyespaces(string player, string opponent)
    {
        return "
            foreach (eyespace; " ~ player ~ "_eyespaces){
                if (eyespace.playing_area.popcount < size_limit){
                    auto result = calculate_status!T(eyespace, defense_transposition_table);
                    if (result.status == Status.retainable){
                        " ~ player ~ "_retainable |= eyespace.playing_area & ~" ~ opponent ~ "_secure;
                    }
                    else if (result.status == Status.defendable){
                        " ~ player ~ "_defendable |= eyespace.playing_area & ~" ~ opponent ~ "_secure;
                    }
                    else if (result.status == Status.secure){
                        " ~ player ~ "_secure |= eyespace.playing_area & ~" ~ opponent ~ "_secure;
                    }
                    else{
                        " ~ player ~ "_deferred[eyespace] = result;
                    }

                    //" ~ player ~ "_useless |= result.player_useless;
                    //" ~ opponent ~ "_useless |= result.opponent_useless;
                }
            }
        ";
    }

    mixin(analyze_eyespaces("player", "opponent"));
    mixin(analyze_eyespaces("opponent", "player"));

    string analyze_death(string player, string opponent)
    {
        return "
            foreach (eyespace, result; " ~ player ~"_deferred){
                auto liberties = eyespace.playing_area.liberties(state.playing_area);
                auto defendable = " ~ opponent ~ "_defendable | " ~ opponent ~ "_secure;
                if (result.status == Status.dead){
                    if (!(liberties & ~" ~ opponent ~ "_secure)){
                        " ~ opponent ~ "_secure |= eyespace.playing_area;
                    }
                    else if (!(liberties & ~defendable)){
                        " ~ opponent ~ "_defendable |= eyespace.playing_area;
                    }
                }
                else if (result.status == Status.killable){
                    if (!(liberties & ~defendable)){
                        " ~ opponent ~ "_defendable |= eyespace.playing_area;
                    }
                }
            }
        ";
    }

    mixin(analyze_death("player", "opponent"));
    mixin(analyze_death("opponent", "player"));

    player_useless = player_defendable;
    if (!state.ko){
        player_useless |= opponent_retainable | opponent_defendable;
    }

    float lower_bound;
    float upper_bound;

    calculate_bounds!(T, C)(
        state, player_retainable, opponent_retainable, player_defendable, opponent_defendable, player_secure, opponent_secure,
        lower_bound, upper_bound
    );

    static if (is (C == CanonicalDefenseState!T)){
        if (state.player_target){
            lower_bound = -float.infinity;
        }
        if (state.opponent_target){
            upper_bound = float.infinity;
        }
    }

    float score = controlled_liberty_score!(T, C)(state, player_retainable, opponent_retainable, player_defendable, opponent_defendable, player_secure, opponent_secure);

    return DefenseAnalysisResult!T(
        player_secure, opponent_secure,
        player_defendable | player_retainable, opponent_defendable | opponent_retainable,
        player_useless, lower_bound, upper_bound, score
    );
}

DefenseAnalysisResult!T analyze_state_light(T, C)(C state, T player_secure, T opponent_secure)
{
    float lower_bound;
    float upper_bound;

    calculate_bounds!(T, C)(
        state, T(), T(), T(), T(), player_secure, opponent_secure,
        lower_bound, upper_bound
    );

    static if (is (C == CanonicalDefenseState!T)){
        if (state.player_target){
            lower_bound = -float.infinity;
        }
        if (state.opponent_target){
            upper_bound = float.infinity;
        }
    }

    float score = controlled_liberty_score!(T, C)(state, T(), T(), T(), T(), player_secure, opponent_secure);

    return DefenseAnalysisResult!T(player_secure, opponent_secure, T(), T(), T(), lower_bound, upper_bound, score);
}

void calculate_bounds(T, C)(
    C state, T player_retainable, T opponent_retainable, T player_defendable, T opponent_defendable, T player_secure, T opponent_secure,
    out float lower_bound, out float upper_bound
)
{
    auto player_crawlable = (player_secure | player_defendable).liberties(state.playing_area & ~(state.player | state.opponent));
    auto opponent_crawlable = (opponent_secure | opponent_defendable).liberties(state.playing_area & ~(state.player | state.opponent));

    int player_crawl_score = player_crawlable.popcount;
    player_crawl_score = (player_crawl_score / 2) + (player_crawl_score & 1);
    int opponent_crawl_score = opponent_crawlable.popcount / 2;

    float size = state.playing_area.popcount;

    lower_bound = 2 * (player_secure | player_defendable | player_retainable).popcount + player_crawl_score - size + state.value_shift;
    upper_bound = -(2 * (opponent_secure | opponent_defendable | opponent_retainable).popcount + opponent_crawl_score - size) + state.value_shift;
}

float controlled_liberty_score(T, C)(C state, T player_retainable, T opponent_retainable, T player_defendable, T opponent_defendable, T player_secure, T opponent_secure)
in
{
    assert(state.black_to_play);
}
body
{
    float score = state.target_score;

    if (score == 0){
        player_retainable |= player_defendable | player_secure;
        opponent_retainable |= opponent_defendable | opponent_secure;

        auto player_controlled_terrirory = (state.player | player_retainable) & ~opponent_retainable;
        auto opponent_controlled_terrirory = (state.opponent | opponent_retainable) & ~player_retainable;

        score += player_controlled_terrirory.popcount;
        score -= opponent_controlled_terrirory.popcount;

        score += player_controlled_terrirory.liberties(state.playing_area & ~opponent_controlled_terrirory).popcount;
        score -= opponent_controlled_terrirory.liberties(state.playing_area & ~player_controlled_terrirory).popcount;

        return score + state.value_shift;
    }
    else{
        return score;
    }
}


unittest
{
    Transposition[DefenseState8] empty;
    auto defense_transposition_table = &empty;

    auto space = rectangle8(3, 1).south.east;
    auto wings = Board8(1, 1) | Board8(3, 1);
    auto player = rectangle8(5, 3) & ~space;
    auto s = DefenseState8(space | player);
    s.player = player;
    s.player_target = player;
    auto result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.contested);
    assert(result.player_useless == wings);
    assert(result.opponent_useless == wings);

    s.player_outside_liberties = 2;
    result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.contested);
    assert(result.player_useless == wings);
    assert(result.opponent_useless == wings);

    s.opponent |= Board8(2, 1);
    result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.dead || result.status == Status.killable);

    space = rectangle8(4, 1).south.east;
    wings = Board8(1, 1) | Board8(4, 1);
    player = rectangle8(6, 3) & ~space;
    s = DefenseState8(space | player);
    s.player = player;
    s.player_target = player;
    result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.defendable);
    assert(result.player_useless == wings);
    assert(result.opponent_useless == wings);

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

    space = rectangle8(3, 1) | Board8(0, 1);
    wings = space & ~rectangle8(2, 1);
    player = rectangle8(4, 3) & ~space;
    s = DefenseState8(space | player);
    s.player = player;
    s.player_target = player;
    s.player_outside_liberties = 2;
    result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.retainable);
    assert(result.player_useless == wings);
    assert(result.opponent_useless == wings);

    space = rectangle8(3, 2);
    wings = space & ~(Board8(1, 0) | Board8(1, 1));
    player = rectangle8(4, 3) & ~space;
    s = DefenseState8(space | player);
    s.player = player;
    s.player_target = player;
    s.player_outside_liberties = 2;
    result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.retainable);
    assert(result.player_useless == wings);
    assert(!result.opponent_useless);

    s = DefenseState8(rectangle8(4, 3));
    s.player = rectangle8(4, 3) & ~(rectangle8(2, 2) | Board8(3, 0) | Board8(3, 1));
    s.player_target = s.player;
    result = calculate_status8(s, defense_transposition_table);
    assert(result.status == Status.secure);

    Board8 player_secure, opponent_secure;
    DefenseState8[] player_eyespaces;
    DefenseState8[] opponent_eyespaces;

    extract_eyespaces!(Board8, DefenseState8)(s, player_secure, opponent_secure, player_eyespaces, opponent_eyespaces);

    bool all_extracted = false;
    foreach (player_eyespace; player_eyespaces){
        if (player_eyespace.playing_area.popcount == s.playing_area.popcount){
            all_extracted = true;
        }
    }
    assert(all_extracted);

    s = DefenseState8();
    s.player = rectangle8(5, 2) & ~rectangle8(4, 1);
    s.opponent = (rectangle8(6, 2) & ~rectangle8(5, 1).south).south(5);

    s.player |= Board8(1, 6);
    s.opponent |= Board8(1, 0);
    s.player |= Board8(3, 3) | Board8(4, 3) | Board8(6, 6);
    s.opponent |= Board8(5, 0) | Board8(6, 4);


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
