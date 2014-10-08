module search_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import board8;
import state;


class BaseSearchState(T)
{
    State!T state;
    float lower_bound = -float.infinity;
    float upper_bound = float.infinity;
    bool is_leaf;
    BaseSearchState!T[] children;
    BaseSearchState!T[State!T] parents;

    public
    {
        State!T canonical_state;
        T[] moves;
        BaseSearchState!T[] allocated_children;
        bool is_loop_terminal;
    }
}


class SearchState(T) : BaseSearchState!T
{
    T player_unconditional;
    T opponent_unconditional;

    invariant
    {
        assert(!(player_unconditional & opponent_unconditional));
        assert(state.passes <= 2);
        State!T temp = state;
        temp.canonize;
        assert(temp == canonical_state);
        if (is_leaf){
            // TODO: Find out why this breaks.
            //assert((lower_bound.isNaN && upper_bound.isNaN) || (lower_bound == upper_bound));
        }
    }

    this(T playing_area)
    {
        state = State!T(playing_area);
        canonical_state = state;
        canonical_state.canonize;
        calculate_available_moves;

        if (state.passes >= 2){
            is_leaf = true;
            lower_bound = upper_bound = liberty_score;
        }
    }

    this(State!T state, State!T canonical_state, T player_unconditional, T opponent_unconditional, T[] moves=null)
    {
        this.state = state;
        this.canonical_state = canonical_state;
        this.player_unconditional = player_unconditional;
        this.opponent_unconditional = opponent_unconditional;
        analyze_unconditional;
        if (state.passes >= 2){
            is_leaf = true;
            lower_bound = upper_bound = liberty_score;
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

    ~this()
    {
        foreach(child; allocated_children){
            destroy(child);
        }
    }

    int liberty_score()
    {
        int score = 0;

        auto player_controlled_area = (state.player | player_unconditional) & ~opponent_unconditional;
        auto opponent_controlled_area = (state.opponent | opponent_unconditional) & ~player_unconditional;

        score += player_controlled_area.popcount;
        score -= opponent_controlled_area.popcount;

        score += player_controlled_area.liberties(state.playing_area & ~opponent_controlled_area).popcount;
        score -= opponent_controlled_area.liberties(state.playing_area & ~player_controlled_area).popcount;

        if (state.black_to_play){
            return score;
        }
        else{
            return -score;
        }
    }

    void analyze_unconditional()
    {
        state.analyze_unconditional(player_unconditional, opponent_unconditional);
    }

    void calculate_available_moves()
    {
        for (int y = 0; y < T.HEIGHT; y++){
            for (int x = 0; x < T.WIDTH; x++){
                T move = T(x, y);
                if (move & state.playing_area){
                    moves ~= move;
                }
            }
        }
        moves ~= T();

        prune_moves;
    }

    void prune_moves()
    {
        T[] temp;
        foreach (move; moves){
            if (!move){
                temp ~= move;
            }
            else if (move & ~player_unconditional & ~opponent_unconditional){
                temp ~= move;
            }
        }
        moves = temp;
    }

    void make_children(SearchState!T[State!T] state_pool)
    {
        children = [];
        auto child_states = state.children(moves);

        // Prune out transpositions.
        State!T[] canonical_child_states;
        State!T[] temp;
        bool[State!T] seen;
        foreach (child_state; child_states){
            auto canonical_child_state = child_state;
            canonical_child_state.canonize;
            if (canonical_child_state !in seen){
                seen[canonical_child_state] = true;
                temp ~= child_state;
                canonical_child_states ~= canonical_child_state;
            }
        }
        child_states = temp;

        foreach (index, child_state; child_states){
            auto canonical_child_state = canonical_child_states[index];
            if (canonical_state in state_pool){
                auto child = state_pool[canonical_child_state];
                children ~= child;
                child.parents[canonical_state] = this;
            }
            else{
                assert(child_state.black_to_play != state.black_to_play);
                auto child = new SearchState!T(
                    child_state,
                    canonical_child_state,
                    opponent_unconditional,
                    player_unconditional,
                    moves
                );
                allocated_children ~= child;
                children ~= child;
                child.parents[canonical_state] = this;
            }
        }

        children.randomShuffle;

        static bool is_better(BaseSearchState!T a, BaseSearchState!T b){
            if (a.is_leaf && !b.is_leaf){
                return true;
            }
            if (b.is_leaf && !a.is_leaf){
                return false;
            }
            if (a.state.passes < b.state.passes){
                return true;
            }
            if (b.state.passes < a.state.passes){
                return false;
            }
            if (a.parents.length < b.parents.length){
                return true;
            }
            if (b.parents.length < a.parents.length){
                return false;
            }

            int a_unconditional = (cast(SearchState!T)a).opponent_unconditional.popcount;
            a_unconditional -= (cast(SearchState!T)a).player_unconditional.popcount;
            int b_unconditional = (cast(SearchState!T)b).opponent_unconditional.popcount;
            b_unconditional -= (cast(SearchState!T)b).player_unconditional.popcount;

            if (a_unconditional > b_unconditional){
                return true;
            }
            if (b_unconditional > a_unconditional){
                return false;
            }

            int a_euler = a.state.opponent.euler - a.state.player.euler;
            int b_euler = b.state.opponent.euler - b.state.player.euler;

            if (a_euler > b_euler){
                return true;
            }
            if (b_euler > a_euler){
                return false;
            }

            int a_popcount = a.state.opponent.popcount - a.state.player.popcount;
            int b_popcount = b.state.opponent.popcount - b.state.player.popcount;

            if (a_popcount > b_popcount){
                return true;
            }

            return false;
        }

        sort!is_better(children);

    }

    void calculate_minimax_value(
        ref SearchState!T[State!T] state_pool,
        bool[State!T] history,
        float depth=float.infinity,
        float alpha=-float.infinity,
        float beta=float.infinity
    )
    {
        if (is_leaf){
            return;
        }

        if (is_loop_terminal){
            return;
        }

        if (depth <= 0){
            return;
        }

        if (canonical_state in history){
            // Do a short search instead?
            is_loop_terminal = true;
            return;
        }
        history = history.dup;
        history[canonical_state] = true;

        if (!children.length){
            make_children(state_pool);
        }

        foreach (child; children){
            if (state.black_to_play){
                if (lower_bound > alpha){
                    alpha = lower_bound;
                }
            }
            else{
                if (upper_bound < beta){
                    beta = upper_bound;
                }
            }

            if (beta <= alpha){
                return;
            }

            (cast(SearchState!T)child).calculate_minimax_value(state_pool, history, depth - 1, alpha, beta);
            bool changed = update_value; // TODO: Do single updates.
            if (changed){
                // Update parents?
            }
        }
    }

    void calculate_minimax_value(float depth=float.infinity)
    {

        SearchState!T[State!T] state_pool;
        bool[State!T] history;
        calculate_minimax_value(state_pool, history, depth, -float.infinity, float.infinity);
    }

    void iterative_deepening_search(int min_depth, int max_depth)
    {
        SearchState!T[State!T] state_pool;
        bool[State!T] history;
        for (int i = min_depth; i <= max_depth; i++){
            calculate_minimax_value(state_pool, history, i, lower_bound, upper_bound);
        }
    }


    // TODO: Handle transpositions!
    bool update_value()
    {
        if (is_leaf){
            // The value should've been set in the constructor.
            return false;
        }

        float old_lower_bound = lower_bound;
        float old_upper_bound = upper_bound;
        float sign;
        float child_lower_bound, child_upper_bound;
        if (state.black_to_play){
            sign = +1;
        }
        else{
            sign = -1;
        }

        lower_bound = -sign * float.infinity;
        upper_bound = -sign * float.infinity;

        foreach (child; children){
             if (state.black_to_play != child.state.black_to_play){
                    child_lower_bound = child.lower_bound;
                    child_upper_bound = child.upper_bound;
                }
                else{
                    child_lower_bound = -child.upper_bound;
                    child_upper_bound = -child.lower_bound;
                }
                if (child_lower_bound * sign > lower_bound * sign){
                    lower_bound = child_lower_bound;
                }
                if (child_upper_bound * sign > upper_bound * sign){
                    upper_bound = child_upper_bound;
                }
        }

        debug(ss_update_value){
            writeln("Updating value: max=", state.black_to_play);
            writeln("Old value: ", old_lower_bound, ", ", old_upper_bound);
            foreach (child; children){
                writeln(" Child: ", child.lower_bound, ", ", child.upper_bound);
            }
            writeln("New value: ", lower_bound, ", ", upper_bound);
        }

        return (old_lower_bound != lower_bound) || (old_upper_bound != upper_bound);
    }
}


unittest
{
    State!Board8 s = State!Board8(rectangle!Board8(2, 2));
    s.player = Board8(0, 0) | Board8(1, 1);
    auto c = s;
    c.canonize;
    SearchState!Board8 ss = new SearchState!Board8(s, c, Board8(), Board8());

    assert(ss.player_unconditional == ss.state.playing_area);
}

unittest
{
    auto ss = new SearchState!Board8(rectangle!Board8(1, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 0);
    assert(ss.upper_bound == 0);

    ss = new SearchState!Board8(rectangle!Board8(2, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == -2);
    assert(ss.upper_bound == 2);

    ss = new SearchState!Board8(rectangle!Board8(3, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 3);
    assert(ss.upper_bound == 3);

    ss = new SearchState!Board8(rectangle!Board8(4, 1));
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == 4);
    assert(ss.upper_bound == 4);

    ss = new SearchState!Board8(rectangle!Board8(2, 2));
    ss.calculate_minimax_value(8);
    assert(ss.lower_bound == -4);
    assert(ss.upper_bound == 4);

    ss = new SearchState!Board8(rectangle!Board8(3, 2));
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == -6);
    assert(ss.upper_bound == 6);
}