module defense_search_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import board8;
import state;
import search_state;


class DefenseSearchState(T) : BaseSearchState!T
{
    T player_target;
    T opponent_target;

    invariant
    {
        assert(state.black_to_play);
    }

    this(T playing_area)
    {
        state = State!T(playing_area);
        state.black_to_play = true;
        calculate_available_moves;
    }

    this (State!T state, T player_target, T opponent_target){
        state.black_to_play = true;
        this.state = state;
        this.player_target = player_target;
        this.opponent_target = opponent_target;
        analyze_unconditional;
        calculate_available_moves;
    }

    this(State!T state, T player_unconditional, T opponent_unconditional, T player_target, T opponent_target, T[] moves=null)
    {
        assert(state.black_to_play);
        this.state = state;
        this.player_unconditional = player_unconditional;
        this.opponent_unconditional = opponent_unconditional;
        this.player_target = player_target;
        this.opponent_target = opponent_target;
        analyze_unconditional;
        if (state.passes >= 2){
            is_leaf = true;
            lower_bound = upper_bound = liberty_score;
            return;
        }
        if (player_target & ~state.player){
            is_leaf = true;
            lower_bound = upper_bound = -float.infinity;
            return;
        }
        // Suicide is prohibited so it is not possible kill your own target.
        assert(!(opponent_target & ~state.opponent));

        if (moves is null){
            calculate_available_moves;
        }
        else{
            this.moves = moves;
            prune_moves;
        }
    }

    void make_children(ref DefenseSearchState!T[State!T] state_pool)
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
                auto child = new DefenseSearchState!T(
                    child_state,
                    opponent_unconditional,
                    player_unconditional,
                    opponent_target,
                    player_target,
                    moves
                );
                allocated_children ~= child;
                children ~= child;
                child.parents[state] = this;
                state_pool[child_state] = child;
            }
        }

        children.randomShuffle;

        sort!(is_better!T)(children);

    }

    void calculate_minimax_value(
        ref DefenseSearchState!T[State!T] state_pool,
        ref HistoryNode!(State!T) history,
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


        auto my_history = new HistoryNode!(State!T)(state, history);
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

            (cast(DefenseSearchState!T)child).calculate_minimax_value(state_pool, my_history, depth - 1, -beta, -alpha);

            changed = update_value; // TODO: Do single updates.
            if (changed){
                //update_parents;
            }
        }
    }

    void calculate_minimax_value(float depth=float.infinity)
    {

        DefenseSearchState!T[State!T] state_pool;
        HistoryNode!(State!T) history = null;
        calculate_minimax_value(state_pool, history, depth, -float.infinity, float.infinity);
    }

    void iterative_deepening_search(int min_depth, int max_depth)
    {
        DefenseSearchState!T[State!T] state_pool;
        HistoryNode!(State!T) history = null;
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

alias DefenseSearchState8 = DefenseSearchState!Board8;

unittest
{
    auto ss = new DefenseSearchState!Board8(rectangle!Board8(1, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 0);
    assert(ss.upper_bound == 0);

    ss = new DefenseSearchState!Board8(rectangle!Board8(2, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == -2);
    assert(ss.upper_bound == 2);

    ss = new DefenseSearchState!Board8(rectangle!Board8(3, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 3);
    assert(ss.upper_bound == 3);

    ss = new DefenseSearchState!Board8(rectangle!Board8(4, 1));
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == 4);
    assert(ss.upper_bound == 4);

    ss = new DefenseSearchState!Board8(rectangle!Board8(2, 2));
    ss.calculate_minimax_value(8);
    assert(ss.lower_bound == -4);
    assert(ss.upper_bound == 4);

    ss = new DefenseSearchState!Board8(rectangle!Board8(3, 2));
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == -6);
    assert(ss.upper_bound == 6);
}

unittest
{
    auto s = State8(rectangle8(3, 2));
    s.player = Board8(0, 0) | Board8(1, 0) | Board8(2, 0);
    auto ds = new DefenseSearchState8(s, s.player, Board8());

    ds.calculate_minimax_value;
    assert(ds.lower_bound == 6);
    assert(ds.upper_bound == 6);

    s = State8(rectangle8(3, 2));
    s.opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0);
    ds = new DefenseSearchState8(s, Board8(), s.opponent);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);

    s = State8(rectangle8(4, 2));
    s.opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0) | Board8(3, 0);
    ds = new DefenseSearchState8(s, Board8(), s.opponent);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == -8);
    assert(ds.upper_bound == -8);
}

version(all_tests){
    unittest
    {
        // Rectangular six in the corner with two outside liberties.
        s = State8();
        s.opponent = rectangle8(4, 3);
        s.player = s.playing_area & ~s.opponent & ~Board8(6, 0) & ~Board8(7, 1) & ~Board8(4, 0) & ~Board8(4, 1);
        s.opponent &= ~rectangle8(3, 2);
        ds = new DefenseSearchState8(s, Board8(), s.opponent);

        ds.calculate_minimax_value;
        assert(ds.lower_bound == 32);
        assert(ds.upper_bound == 32);

        // Rectangular six in the corner with no outside liberties and one ko threat.
        s = State8();
        s.player = rectangle8(8, 4) & ~rectangle8(4, 3) & ~Board8(6, 0) & ~Board8(7, 1);
        s.player |= rectangle8(5, 2).south(5) & ~rectangle8(4, 1).south(6);
        s.opponent = rectangle8(4, 3) & ~rectangle8(3, 2);
        s.opponent |= rectangle8(8, 3).south(4) & ~rectangle8(5, 2).south(5);
        s.opponent &= ~Board8(6, 6) & ~Board8(7, 5);
        ds = new DefenseSearchState8(s, s.player, s.opponent);

        ds.calculate_minimax_value;
        assert(ds.lower_bound == float.infinity);
        assert(ds.upper_bound == float.infinity);

        // Rectangular six in the corner with one outside liberty and one ko threat.
        s.player &= ~Board8(4, 0);
        ds = new DefenseSearchState8(s, s.player, s.opponent);

        ds.calculate_minimax_value;
        assert(ds.lower_bound == 4);
        assert(ds.upper_bound == 4);
    }
}