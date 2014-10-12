module defense_search_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import polyomino;
import board8;
import defense_state;
import search_state;


class DefenseSearchState(T, S) : BaseSearchState!(T, S)
{
    invariant
    {
        assert(state.black_to_play);
    }

    this(T playing_area)
    {
        this(S(playing_area));
    }

    this (S state){
        state.canonize;
        this.state = state;
        analyze_secure;
        calculate_available_moves;
    }

    this(S state, T player_secure, T opponent_secure, T[] moves=null)
    {
        assert(state.black_to_play);
        this.state = state;
        this.player_secure = player_secure;
        this.opponent_secure = opponent_secure;
        analyze_secure;
        if (state.passes >= 2){
            is_leaf = true;
            lower_bound = upper_bound = liberty_score;
            return;
        }

        if (state.player_target & ~state.player || state.player_target & opponent_secure){
            is_leaf = true;
            lower_bound = upper_bound = -float.infinity;
            return;
        }
        // Suicide is prohibited so it is not possible kill your own target.
        assert(!(state.opponent_target & ~state.opponent));
        // It is however possible to blunder forfeit your stones to the opponent control.
        if (state.opponent_target & player_secure){
            is_leaf = true;
            lower_bound = upper_bound = float.infinity;
            return;
        }

        if (moves is null){
            calculate_available_moves;
        }
        else{
            this.moves = moves;
            prune_moves;
        }
    }

    void make_children(ref DefenseSearchState!(T, S)[S] state_pool)
    {
        children = [];
        auto child_states = state.children(moves);

        // Prune out transpositions?

        foreach (child_state; child_states){
            child_state.black_to_play = true;
            if (child_state in state_pool){
                auto child = state_pool[child_state];
                children ~= child;
                child.parents[state] = this;
            }
            else{
                assert(child_state.black_to_play == state.black_to_play);
                auto child = new DefenseSearchState!(T, S)(
                    child_state,
                    opponent_secure,
                    player_secure,
                    moves
                );
                allocated_children ~= child;
                children ~= child;
                child.parents[state] = this;
                state_pool[child_state] = child;
            }
        }

        children.randomShuffle;

        sort!(is_better!(T, S))(children);

    }

    /*
    void make_children(ref DefenseSearchState!(T, S)[S] state_pool)
    {
        children = [];

        // Prune out transpositions.
        S[] child_states;
        Transformation[] child_transformations;
        int[] child_fixes;
        bool[S] seen;
        foreach (child_state; state.children(effective_moves)){
            int westwards, northwards;
            auto child_transformation = child_state.canonize(westwards, northwards);
            if (child_state !in seen){
                seen[child_state] = true;
                child_states ~= child_state;
                child_transformations ~= child_transformation;
                child_fixes ~= westwards;
                child_fixes ~= northwards;
            }
        }

        foreach (index, child_state; child_states){
            if (child_state in state_pool){
                auto child = state_pool[child_state];
                children ~= child;
                child.parents[state] = this;
            }
            else{
                assert(child_state.black_to_play);

                auto child_player_defendable = opponent_defendable;
                auto child_opponent_defendable = player_defendable;
                auto child_player_secure = opponent_secure;
                auto child_opponent_secure = player_secure;

                auto child_transformation = child_transformations[index];
                int westwards = child_fixes[2 * index];
                int northwards = child_fixes[2 * index + 1];

                child_player_defendable.transform(child_transformation);
                child_player_defendable.fix(westwards, northwards);
                child_opponent_defendable.transform(child_transformation);
                child_opponent_defendable.fix(westwards, northwards);
                child_player_secure.transform(child_transformation);
                child_player_secure.fix(westwards, northwards);
                child_opponent_secure.transform(child_transformation);
                child_opponent_secure.fix(westwards, northwards);

                T[] child_moves;
                foreach(move; moves){
                    move.transform(child_transformation);
                    move.fix(westwards, northwards);
                    child_moves ~= move;
                }

                auto child = new DefenseSearchState!(T, S)(
                    child_state,
                    //child_player_defendable,
                    //child_opponent_defendable,
                    child_player_secure,
                    child_opponent_secure,
                    //defense_table,
                    child_moves,
                );
                allocated_children ~= child;
                children ~= child;
                child.parents[state] = this;
                state_pool[child_state] = child;
            }
        }

        children.randomShuffle;

        sort!(is_better!(T, S))(children);
    }
    */

    void calculate_minimax_value(
        ref DefenseSearchState!(T, S)[S] state_pool,
        ref HistoryNode!(S) history,
        float depth=float.infinity,
        float alpha=-float.infinity,
        float beta=float.infinity
    )
    {
        if (is_leaf){
            return;
        }

        if (depth <= 0){
            return;
        }

        if (history !is null && state in history){
            // Do a short search instead?
            return;
        }


        auto my_history = new HistoryNode!(S)(state, history);
        allocated_history_nodes ~= my_history;

        if (!children.length){
            make_children(state_pool);
        }

        // Check for leaves and transpositions.
        bool changed = update_value;
        if (changed){
            update_parents;
        }

        foreach (child; children){
            if (lower_bound > alpha){
                alpha = lower_bound;
            }
            if (upper_bound < beta){
                beta = upper_bound;
            }

            if (beta <= alpha){
                return;
            }

            (cast(DefenseSearchState!(T, S))child).calculate_minimax_value(state_pool, my_history, depth - 1, -beta, -alpha);

            changed = update_value; // TODO: Do single updates.
            if (changed){
                //update_parents;
            }
        }
    }

    void calculate_minimax_value(float depth=float.infinity)
    {

        DefenseSearchState!(T, S)[S] state_pool;
        HistoryNode!(S) history = null;
        calculate_minimax_value(state_pool, history, depth, -float.infinity, float.infinity);
    }

    void iterative_deepening_search(int min_depth, int max_depth)
    {
        DefenseSearchState!(T, S)[S] state_pool;
        HistoryNode!(S) history = null;
        for (int i = min_depth; i <= max_depth; i++){
            calculate_minimax_value(state_pool, history, i, lower_bound, upper_bound);
        }
    }


    override bool update_value()
    {
        if (is_leaf){
            // The value should've been set in the constructor.
            return false;
        }

        float old_lower_bound = lower_bound;
        float old_upper_bound = upper_bound;

        lower_bound = -float.infinity;
        upper_bound = -float.infinity;

        foreach (child; children){
            if (-child.upper_bound > lower_bound){
                lower_bound = -child.upper_bound;
            }
            if (-child.lower_bound > upper_bound){
                upper_bound = -child.lower_bound;
            }
        }

        debug(ss_update_value){
            if (lower_bound > -float.infinity && upper_bound < float.infinity){
                writeln("Updating value: max=", state.black_to_play);
                writeln("Old value: ", old_lower_bound, ", ", old_upper_bound);
                foreach (child; children){
                    writeln(" Child: ", child.lower_bound, ", ", child.upper_bound, " max=", child.state.black_to_play);
                }
                writeln("New value: ", lower_bound, ", ", upper_bound);
            }
        }

        return (old_lower_bound != lower_bound) || (old_upper_bound != upper_bound);
    }
}

alias DefenseSearchState8 = DefenseSearchState!(Board8, DefenseState8);


unittest
{
    auto ss = new DefenseSearchState8(rectangle8(1, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 0);
    assert(ss.upper_bound == 0);

    ss = new DefenseSearchState8(rectangle8(2, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == -2);
    assert(ss.upper_bound == 2);

    ss = new DefenseSearchState8(rectangle8(3, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 3);
    assert(ss.upper_bound == 3);

    ss = new DefenseSearchState8(rectangle8(4, 1));
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == 4);
    assert(ss.upper_bound == 4);

    ss = new DefenseSearchState8(rectangle8(2, 2));
    ss.calculate_minimax_value(8);
    assert(ss.lower_bound == -4);
    assert(ss.upper_bound == 4);

    ss = new DefenseSearchState8(rectangle8(3, 2));
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == -6);
    assert(ss.upper_bound == 6);
}

unittest
{
    auto s = DefenseState8(rectangle8(3, 2));
    s.player = Board8(0, 0) | Board8(1, 0) | Board8(2, 0);
    s.player_target = s.player;
    auto ds = new DefenseSearchState8(s);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == 6);
    assert(ds.upper_bound == 6);

    s = DefenseState8(rectangle8(3, 2));
    s.opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0);
    s.opponent_target = s.opponent;
    ds = new DefenseSearchState8(s);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);

    s = DefenseState8(rectangle8(4, 2));
    s.opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0) | Board8(3, 0);
    s.opponent_target = s.opponent;
    ds = new DefenseSearchState8(s);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == -8);
    assert(ds.upper_bound == -8);
}

version(all_tests){
    unittest
    {
        // Rectangular six in the corner with two physical outside liberties.
        auto s = DefenseState8();
        s.opponent = rectangle8(4, 3);
        s.player = s.playing_area & ~s.opponent & ~Board8(6, 0) & ~Board8(7, 1) & ~Board8(4, 0) & ~Board8(4, 1);
        s.opponent &= ~rectangle8(3, 2);
        s.opponent_target = s.opponent;
        auto ds = new DefenseSearchState8(s);

        ds.calculate_minimax_value;
        assert(ds.lower_bound == 32);
        assert(ds.upper_bound == 32);

        // Rectangular six in the corner with no outside liberties and one physical ko threat.
        s = DefenseState8();
        s.player = rectangle8(8, 4) & ~rectangle8(4, 3) & ~Board8(6, 0) & ~Board8(7, 1);
        s.player |= rectangle8(5, 2).south(5) & ~rectangle8(4, 1).south(6);
        s.opponent = rectangle8(4, 3) & ~rectangle8(3, 2);
        s.opponent |= rectangle8(8, 3).south(4) & ~rectangle8(5, 2).south(5);
        s.opponent &= ~Board8(6, 6) & ~Board8(7, 5);
        s.player_target = s.player;
        s.opponent_target = s.opponent;
        ds = new DefenseSearchState8(s);

        ds.calculate_minimax_value;
        assert(ds.lower_bound == float.infinity);
        assert(ds.upper_bound == float.infinity);

        // Rectangular six in the corner with one physical outside liberty and one physical ko threat.
        s.player &= ~Board8(4, 0);
        s.player_target = s.player;
        s.opponent_target = s.opponent;
        ds = new DefenseSearchState8(s);

        ds.calculate_minimax_value;
        assert(ds.lower_bound == 4);
        assert(ds.upper_bound == 4);
    }
}

unittest
{
    //Rectangular six in the corner with no outside liberties and infinite ko threats.
    auto s = DefenseState8();
    s.opponent = rectangle8(4, 3) & ~rectangle8(3, 2);
    s.opponent_target = s.opponent;
    s.player = rectangle8(5, 4) & ~rectangle8(4, 3);
    s.player_outside_liberties = s.player;
    s.playing_area = rectangle8(5, 4);
    s.ko_threats = -float.infinity;
    auto ds = new DefenseSearchState8(s);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.lower_bound == float.infinity);

    // Rectangular six in the corner with one outside liberty and no ko threats.
    s.player &= ~Board8(4, 0);
    s.ko_threats = 0;
    ds = new DefenseSearchState8(s);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);

    // Rectangular six in the corner with one outside liberty and one ko threat.
    s.ko_threats = -1;
    ds = new DefenseSearchState8(s);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == -4);
    assert(ds.upper_bound == -4);

    // Rectangular six in the corner with two outside liberties and infinite ko threats for the invader.
    s.player &= ~Board8(4, 1);
    s.ko_threats = float.infinity;
    ds = new DefenseSearchState8(s);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == -4);
    assert(ds.upper_bound == -4);
}

unittest
{
    // Test a state where the opponent can forfeit her stones.
    auto opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0);
    auto space = Board8(0, 1) | Board8(1, 1) | Board8(2, 1) | Board8(1, 2);
    auto s = DefenseState8();
    s.playing_area = space | opponent;
    s.opponent = opponent;
    s.opponent_target = opponent;

    auto ds = new DefenseSearchState8(s);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);
}