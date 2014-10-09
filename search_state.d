module search_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import board8;
import state;


class HistoryNode(T)
{
    T value;
    HistoryNode!T parent = null;

    this(T value){
        this.value = value;
    }

    this(T value, ref HistoryNode!T parent){
        this.value = value;
        this.parent = parent;
    }

    bool opBinaryRight(string op)(in T lhs) const pure nothrow @nogc @safe
        if (op == "in")
    {
        if (lhs == value){
            return true;
        }
        if (parent !is null){
            return parent.opBinaryRight!"in"(lhs);
        }
        return false;
    }
}


class BaseSearchState(T, S)
{
    S state;
    float lower_bound = -float.infinity;
    float upper_bound = float.infinity;
    bool is_leaf;
    BaseSearchState!(T, S)[] children;
    BaseSearchState!(T, S)[S] parents;

    T player_unconditional;
    T opponent_unconditional;

    public
    {
        T[] moves;
        BaseSearchState!(T, S)[] allocated_children;
        HistoryNode!(S)[] allocated_history_nodes;
    }

    invariant
    {
        assert(!(player_unconditional & opponent_unconditional));
        assert(state.passes <= 2);

        // TODO: Find out why this breaks.
        //if (is_leaf){
        //    assert(lower_bound == upper_bound);
        //}
    }

    ~this()
    {
        foreach(child; allocated_children){
            destroy(child);
        }
        foreach(history_node; allocated_history_nodes){
            destroy(history_node);
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
        if (!player_unconditional && !opponent_unconditional){
            return;
        }
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

    bool update_value(){
        return false;
    }

    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        BaseSearchState!(T, S)[] queue;
        foreach (parent; parents.byValue){
            queue ~= parent;
        }

        while (queue.length){
            auto search_state = queue.front;
            queue.popFront;
            debug(update_parents) {
                writeln("Updating parents for:");
                writeln(search_state);
            }
            bool changed = search_state.update_value;
            if (changed){
                foreach (parent; search_state.parents){
                    queue ~= parent;
                }
            }
        }
    }
}

static bool is_better(T, S)(BaseSearchState!(T, S) a, BaseSearchState!(T, S) b){
    if (a.is_leaf && !b.is_leaf){
        return false;
    }
    if (b.is_leaf && !a.is_leaf){
        return true;
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

    int a_unconditional = a.opponent_unconditional.popcount - a.player_unconditional.popcount;
    int b_unconditional = b.opponent_unconditional.popcount - b.player_unconditional.popcount;

    if (a_unconditional > b_unconditional){
        return true;
    }
    if (b_unconditional > a_unconditional){
        return false;
    }

    int a_euler = a.state.opponent.euler - a.state.player.euler;
    int b_euler = b.state.opponent.euler - b.state.player.euler;

    if (a_euler < b_euler){
        return true;
    }
    if (b_euler < a_euler){
        return false;
    }

    int a_popcount = a.state.opponent.popcount - a.state.player.popcount;
    int b_popcount = b.state.opponent.popcount - b.state.player.popcount;

    if (a_popcount > b_popcount){
        return true;
    }

    return false;
}


class SearchState(T, S) : BaseSearchState!(T, S)
{
    public
    {
        S canonical_state;
    }

    invariant
    {
        version(all_invariants){
            S temp = state;
            temp.canonize;
            assert(temp == canonical_state);
        }
    }

    this(T playing_area)
    {
        state = S(playing_area);
        canonical_state = state;
        canonical_state.canonize;
        calculate_available_moves;
    }

    this(S state, S canonical_state, T player_unconditional, T opponent_unconditional, T[] moves=null)
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

    void make_children(ref SearchState!(T, S)[S] state_pool)
    {
        children = [];
        auto child_states = state.children(moves);

        // Prune out transpositions.
        S[] canonical_child_states;
        S[] temp;
        bool[S] seen;
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
            if (canonical_child_state in state_pool){
                auto child = state_pool[canonical_child_state];
                children ~= child;
                child.parents[canonical_state] = this;
            }
            else{
                assert(child_state.black_to_play != state.black_to_play);
                auto child = new SearchState!(T, S)(
                    child_state,
                    canonical_child_state,
                    opponent_unconditional,
                    player_unconditional,
                    moves
                );
                allocated_children ~= child;
                children ~= child;
                child.parents[canonical_state] = this;
                state_pool[canonical_child_state] = child;
            }
        }

        children.randomShuffle;

        sort!(is_better!(T, S))(children);

    }

    void calculate_minimax_value(
        ref SearchState!(T, S)[S] state_pool,
        ref HistoryNode!(S) history,
        float depth=float.infinity,
        float alpha=-float.infinity,
        float beta=float.infinity
    )
    {
        if (is_leaf){
            return;
        }

        //if (is_loop_terminal){
        //    return;
        //}

        if (depth <= 0){
            return;
        }

        if (history !is null && canonical_state in history){
            // Do a short search instead?
            //is_loop_terminal = true;
            return;
            /*
                if (depth >= 3){
                    depth = 3;
                }
            */
        }

        auto my_history = new HistoryNode!(S)(canonical_state, history);
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

            if (state.black_to_play != child.state.black_to_play){
                (cast(SearchState!(T, S))child).calculate_minimax_value(state_pool, my_history, depth - 1, alpha, beta);
            }
            else{
                (cast(SearchState!(T, S))child).calculate_minimax_value(state_pool, my_history, depth - 1, -beta, -alpha);
            }
            changed = update_value; // TODO: Do single updates.
            if (changed){
                //update_parents;
            }
        }
    }

    void calculate_minimax_value(float depth=float.infinity)
    {

        SearchState!(T, S)[S] state_pool;
        HistoryNode!(S) history = null;
        calculate_minimax_value(state_pool, history, depth, -float.infinity, float.infinity);
    }

    void iterative_deepening_search(int min_depth, int max_depth)
    {
        SearchState!(T, S)[S] state_pool;
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

alias SearchState8 = SearchState!(Board8, State8);

unittest
{
    auto s = State8();
    auto h = new HistoryNode!(State8)(s);

    auto child_s = s;
    child_s.player = Board8(3, 3);
    auto child_h = new HistoryNode!(State8)(child_s, h);

    assert(child_s !in h);
    assert(child_s in child_h);
    assert(s in child_h);
}


unittest
{
    State8 s = State8(rectangle8(2, 2));
    s.player = Board8(0, 0) | Board8(1, 1);
    auto c = s;
    c.canonize;
    SearchState8 ss = new SearchState8(s, c, Board8(), Board8());

    assert(ss.player_unconditional == ss.state.playing_area);
}


unittest
{
    auto ss = new SearchState8(rectangle8(1, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 0);
    assert(ss.upper_bound == 0);

    ss = new SearchState8(rectangle8(2, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == -2);
    assert(ss.upper_bound == 2);

    ss = new SearchState8(rectangle8(3, 1));
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 3);
    assert(ss.upper_bound == 3);

    ss = new SearchState8(rectangle8(4, 1));
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == 4);
    assert(ss.upper_bound == 4);

    ss = new SearchState8(rectangle8(2, 2));
    ss.calculate_minimax_value(8);
    assert(ss.lower_bound == -4);
    assert(ss.upper_bound == 4);

    ss = new SearchState8(rectangle8(3, 2));
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == -6);
    assert(ss.upper_bound == 6);

    ss = new SearchState8(rectangle8(3, 3));
    ss.calculate_minimax_value(20);
    assert(ss.lower_bound == 9);
    assert(ss.upper_bound == 9);
}
