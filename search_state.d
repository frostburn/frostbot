module search_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import board8;
import state;

struct Transposition
{
    float lower_bound = -float.infinity;
    float upper_bound = float.infinity;

    this(float lower_bound, float upper_bound)
    {
        this.lower_bound = lower_bound;
        this.upper_bound = upper_bound;
    }
}

class BaseSearchState(T)
{
    State!T state;
    float lower_bound = -float.infinity;
    float upper_bound = float.infinity;
    bool is_leaf;
    BaseSearchState!T[] children;
    BaseSearchState!T parent;

    public
    {
        State!T canonical_state;
        T[] moves;
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

    this(State!T state, State!T canonical_state, T player_unconditional, T opponent_unconditional, T[] moves=null, SearchState!T parent=null)
    {
        this.state = state;
        this.canonical_state = canonical_state;
        this.player_unconditional = player_unconditional;
        this.opponent_unconditional = opponent_unconditional;
        analyze_unconditional;
        this.parent = parent;
        if (state.passes >= 2){
            is_leaf = true;
            lower_bound = upper_bound = liberty_score;
            return;
        }
        auto search_state = this;
        while (search_state.parent !is null){
            search_state = cast(SearchState!T)(search_state.parent);
            if (search_state.canonical_state == canonical_state){
                is_leaf = true;
                return;
            }
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
        foreach(child; children){
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

    void make_children()
    {
        children = [];
        auto state_children = state.children(moves);

        // Prune out transpositions.
        State!T[] canonical_states;
        State!T[] temp;
        bool[State!T] seen;
        foreach (child_state; state_children){
            auto canonical_state = child_state;
            canonical_state.canonize;
            if (canonical_state !in seen){
                seen[canonical_state] = true;
                temp ~= child_state;
                canonical_states ~= canonical_state;
            }
        }
        state_children = temp;

        foreach (index, child_state; state_children){
            assert(child_state.black_to_play != state.black_to_play);
            children ~= new SearchState!T(
                    child_state,
                    canonical_states[index],
                    opponent_unconditional,
                    player_unconditional,
                    moves,
                    this
                );
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
        ref Transposition[State!T] transposition_table,
        float depth=float.infinity,
        float alpha=-float.infinity,
        float beta=float.infinity
    )
    {
        if (is_leaf){
            return;
        }
        if (canonical_state in transposition_table){
            auto transposition = transposition_table[canonical_state];
            if (state.black_to_play == canonical_state.black_to_play){
                lower_bound = transposition.lower_bound;
                upper_bound = transposition.upper_bound;
            }
            else{
                lower_bound = -transposition.upper_bound;
                upper_bound = -transposition.lower_bound;
            }
        }

        if (depth <= 0){
            return;
        }

        if (!children.length){
            make_children;
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

            (cast(SearchState!T)child).calculate_minimax_value(transposition_table, depth - 1, alpha, beta);
            bool changed = update_value; // TODO: Do single updates.
            if (changed){
                Transposition transposition;
                if (state.black_to_play == canonical_state.black_to_play){
                    transposition.lower_bound = lower_bound;
                    transposition.upper_bound = upper_bound;
                }
                else{
                    transposition.lower_bound = -upper_bound;
                    transposition.upper_bound = -lower_bound;
                }
                transposition_table[canonical_state] = transposition;
                debug(transpositions){
                    writeln(state);
                    writeln(lower_bound, ", ", upper_bound);
                }
            }
        }
    }

    void calculate_minimax_value(float depth=float.infinity)
    {
        Transposition[State!T] transposition_table;
        calculate_minimax_value(transposition_table, depth, -float.infinity, float.infinity);
    }

    void iterative_deepening_search(int min_depth, int max_depth)
    {
        Transposition[State!T] transposition_table;
        for (int i = min_depth; i <= max_depth; i++){
            calculate_minimax_value(transposition_table, i, lower_bound, upper_bound);
        }
    }

    bool update_value()
    {
        if (is_leaf){
            // The value should've been set in the constructor.
            return false;
        }

        float old_lower_bound = lower_bound;
        float old_upper_bound = upper_bound;
        float sign;
        if (state.black_to_play){
            sign = +1;
        }
        else{
            sign = -1;
        }

        bool lower_bound_set = false;
        bool upper_bound_set = false;

        lower_bound = -sign * float.infinity;
        upper_bound = -sign * float.infinity;

        foreach (child; children){
            if (child.lower_bound * sign >= lower_bound * sign){
                lower_bound = child.lower_bound;
                lower_bound_set = true;
            }
            if (child.upper_bound * sign >= upper_bound * sign){
                upper_bound = child.upper_bound;
                upper_bound_set = true;
            }
        }

        if (!lower_bound_set){
            lower_bound = -float.infinity;
        }
        if (!upper_bound_set){
            upper_bound = float.infinity;
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
    ss.calculate_minimax_value(7);
    assert(ss.lower_bound == -6);
    assert(ss.upper_bound == 6);
}