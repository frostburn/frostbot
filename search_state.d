module search_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.math : isNaN;

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
    BaseSearchState!T parent;

    public
    {
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
            assert((lower_bound.isNaN && upper_bound.isNaN) || (lower_bound == upper_bound));
        }
    }

    this(T playing_area)
    {
        state = State!T(playing_area);
        calculate_available_moves;

        if (state.passes >= 2){
            is_leaf = true;
            lower_bound = upper_bound = state.liberty_score;
        }
    }

    this(State!T state, T player_unconditional, T opponent_unconditional, T[] moves=null, SearchState!T parent=null, float super_ko_value=float.nan)
    {
        this.state = state;
        this.player_unconditional = player_unconditional;
        this.opponent_unconditional = opponent_unconditional;
        analyze_unconditional;
        this.parent = parent;
        if (state.passes >= 2){
            is_leaf = true;
            lower_bound = upper_bound = state.liberty_score;
            return;
        }
        auto search_state = this;
        while (search_state.parent !is null){
            search_state = cast(SearchState!T)(search_state.parent);
            if (search_state.state == state){
                is_leaf = true;
                lower_bound = upper_bound = super_ko_value;
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

    invariant
    {
        assert(!(player_unconditional & opponent_unconditional));
        assert(state.passes <= 2);
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

    void make_children(float super_ko_value=float.nan)
    {
        auto state_children = state.children(moves);
        // TODO: Prune out transpositions when they are likely to occur.
        foreach (child_state; state_children){
            assert(child_state.black_to_play != state.black_to_play);
            children ~= new SearchState!T(
                    child_state,
                    opponent_unconditional,
                    player_unconditional,
                    moves,
                    this,
                    super_ko_value
                );
        }
        // TODO: Sort the children.
    }

    void calculate_minimax_value(float depth=float.infinity, float super_ko_value=float.nan)
    {
        if (depth <= 0){
            //lower_bound = upper_bound = state.liberty_score;
            return;
        }

        make_children(super_ko_value);

        foreach (child; children){
            (cast(SearchState!T)child).calculate_minimax_value(depth - 1, super_ko_value);
        }

        update_value;
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
            lower_bound = float.nan;
        }
        if (!upper_bound_set){
            upper_bound = float.nan;
        }

        bool lower_bound_changed = (old_lower_bound != lower_bound);
        if (lower_bound.isNaN && old_lower_bound.isNaN){
            lower_bound_changed = false;
        }
        bool upper_bound_changed = (old_upper_bound != upper_bound);
        if (upper_bound.isNaN && old_upper_bound.isNaN){
            upper_bound_changed = false;
        }

        debug(ss_update_value){
            writeln("Updating value: max=", state.black_to_play);
            writeln("Old value: ", old_lower_bound, ", ", old_upper_bound);
            foreach (child; children){
                writeln(" Child: ", child.lower_bound, ", ", child.upper_bound);
            }
            writeln("New value: ", lower_bound, ", ", upper_bound);
        }

        return lower_bound_changed || upper_bound_changed;
    }
}


unittest
{
    State!Board8 s = State!Board8(rectangle!Board8(2, 2));
    s.player = Board8(0, 0) | Board8(1, 1);
    SearchState!Board8 ss = new SearchState!Board8(s, Board8(), Board8());

    assert(ss.player_unconditional == ss.state.playing_area);
}

unittest
{
    auto ss = new SearchState!Board8(rectangle!Board8(1, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 0);
    assert(ss.upper_bound == 0);

    ss = new SearchState!Board8(rectangle!Board8(2, 1));
    ss.calculate_minimax_value(float.infinity, -float.infinity);
    assert(ss.lower_bound == -2);
    assert(ss.upper_bound == -2);

    ss = new SearchState!Board8(rectangle!Board8(2, 1));
    ss.calculate_minimax_value(float.infinity, float.infinity);
    assert(ss.lower_bound == 2);
    assert(ss.upper_bound == 2);

    ss = new SearchState!Board8(rectangle!Board8(3, 1));
    ss.calculate_minimax_value(float.infinity, -float.infinity);
    assert(ss.lower_bound == 3);
    assert(ss.upper_bound == 3);

    ss = new SearchState!Board8(rectangle!Board8(4, 1));
    ss.calculate_minimax_value(11, -float.infinity);
    assert(ss.lower_bound == 4);
    assert(ss.upper_bound == 4);
}