module search_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import board8;
import state;
import defense_state;
import defense;



class BaseSearchState(T, S)
{
    S state;
    float lower_bound = -float.infinity;
    float upper_bound = float.infinity;
    bool is_leaf;
    BaseSearchState!(T, S)[] children;
    BaseSearchState!(T, S)[S] parents;

    T player_defendable;
    T opponent_defendable;

    T player_secure;
    T opponent_secure;

    T player_useless;
    T opponent_useless;


    public
    {
        T[] moves;
        BaseSearchState!(T, S)[] allocated_children;
        HistoryNode!(S)[] allocated_history_nodes;
    }

    invariant
    {
        //assert(!(player_secure & opponent_secure));
        //assert(!(player_defendable & opponent_defendable));
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

        auto player_controlled_terrirory = (state.player | player_defendable | player_secure) & ~(opponent_defendable | opponent_secure);
        auto opponent_controlled_terrirory = (state.opponent | opponent_defendable | opponent_secure) & ~(player_defendable | player_secure);

        score += player_controlled_terrirory.popcount;
        score -= opponent_controlled_terrirory.popcount;

        score += player_controlled_terrirory.liberties(state.playing_area & ~opponent_controlled_terrirory).popcount;
        score -= opponent_controlled_terrirory.liberties(state.playing_area & ~player_controlled_terrirory).popcount;

        if (state.black_to_play){
            return score;
        }
        else{
            return -score;
        }
    }

    void analyze_defendable(ref DefenseResult!T[DefenseState!T] defense_table)
    {
        DefenseState!T[] player_eyespaces;
        DefenseState!T[] opponent_eyespaces;


        extract_eyespaces!(T, S)(state, player_secure, opponent_secure, player_eyespaces, opponent_eyespaces);

        string analyze_eyespaces(string player, string opponent)
        {
            return "
                foreach (" ~ player ~ "_eyespace; " ~ player ~ "_eyespaces){
                    auto result = calculate_status!T(" ~ player ~ "_eyespace, defense_table, " ~ player ~ "_secure, " ~ opponent ~ "_secure);
                    debug(analyze_defendable){
                        writeln(" ~ player ~ "_eyespace);
                        writeln(result);
                    }
                    if (result.status == Status.defendable){
                        " ~ player ~ "_defendable |= (" ~ player ~ "_eyespace.playing_area & ~" ~ opponent ~ "_secure);
                    }
                    else if (result.status == Status.secure){
                        " ~ player ~ "_secure |= (" ~ player ~ "_eyespace.playing_area & ~" ~ opponent ~ "_secure);
                    }

                    " ~ player ~ "_useless |= result." ~ opponent ~ "_useless;
                    " ~ opponent ~ "_useless |= result." ~ player ~ "_useless;
                }
            ";
        }

        mixin(analyze_eyespaces("player", "opponent"));
        mixin(analyze_eyespaces("opponent", "player"));
    }

    void analyze_secure()
    {
        // Intentionally abusing unconditional life analysis by treating secure territory as unconditional territory.
        state.analyze_unconditional(player_secure, opponent_secure);
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
        if (!player_secure && !opponent_secure){
            return;
        }
        T[] temp;
        foreach (move; moves){
            if (!move){
                temp ~= move;
            }
            else if (move & ~player_secure & ~opponent_secure){
                temp ~= move;
            }
        }
        moves = temp;
    }

    T[] effective_moves()
    {
        T[] result;
        T useless = player_defendable | opponent_defendable | player_useless;

        foreach (move; moves){
            if (!(move & useless)){
                result ~= move;
            }
        }
        return result;
    }

    bool update_value(){
        return false;
    }

    override string toString()
    {
        return format(
            "%s\nlower_bound=%s upper_bound=%s leaf=%s number of children=%s",
            state._toString(player_defendable, opponent_defendable, player_secure, opponent_secure),
            lower_bound,
            upper_bound,
            is_leaf,
            children.length
        );
    }
}


class SearchState(T, S) : BaseSearchState!(T, S)
{
    invariant
    {
        assert(state.black_to_play);
        version(all_invariants){
            S temp = state;
            temp.canonize;
            assert(temp == canonical_state);
        }
    }

    this(T playing_area){
        this(S(playing_area));
    }

    this(S state)
    {
        state.canonize;
        this.state = state;

        DefenseResult!T[DefenseState!T] empty;
        analyze_secure;
        analyze_defendable(empty);

        update_bounds;

        calculate_available_moves;
    }

    this(S state, T player_defendable, T opponent_defendable, T player_secure, T opponent_secure, ref DefenseResult!T[DefenseState!T] defense_table, T[] moves=null)
    {
        this.state = state;
        this.player_defendable = player_defendable;
        if (!state.ko){
            this.opponent_defendable = opponent_defendable;
        }
        this.player_secure = player_secure;
        this.opponent_secure = opponent_secure;

        analyze_secure;
        analyze_defendable(defense_table);
        if (state.is_leaf){
            is_leaf = true;
            lower_bound = upper_bound = liberty_score;
            return;
        }

        update_bounds;

        if (moves is null){
            calculate_available_moves;
        }
        else{
            this.moves = moves;
            prune_moves;
        }
    }

    void update_bounds()
    {
        T player_controlled_terrirory = player_secure | player_defendable;
        T opponent_controlled_terrirory = opponent_secure | opponent_defendable;

        float size = state.playing_area.popcount;

        lower_bound = -size + 2 * player_controlled_terrirory.popcount;
        upper_bound = size - 2 * opponent_controlled_terrirory.popcount;
    }

    void make_children(ref SearchState!(T, S)[S] state_pool, ref DefenseResult!T[DefenseState!T] defense_table)
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

                auto child = new SearchState!(T, S)(
                    child_state,
                    child_player_defendable,
                    child_opponent_defendable,
                    child_player_secure,
                    child_opponent_secure,
                    defense_table,
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

    void calculate_minimax_value(
        ref SearchState!(T, S)[S] state_pool,
        ref HistoryNode!(S) history,
        ref DefenseResult!T[DefenseState!T] defense_table,
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
            //is_loop_terminal = true;
            return;
            /*
                if (depth >= 3){
                    depth = 3;
                }
            */
        }

        auto my_history = new HistoryNode!(S)(state, history);
        allocated_history_nodes ~= my_history;

        if (!children.length){
            make_children(state_pool, defense_table);
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


            (cast(SearchState!(T, S))child).calculate_minimax_value(state_pool, my_history, defense_table, depth - 1, -beta, -alpha);

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
        DefenseResult!T[DefenseState!T] defense_table;
        calculate_minimax_value(state_pool, history, defense_table, depth, -float.infinity, float.infinity);
    }

    void iterative_deepening_search(int min_depth, int max_depth)
    {
        SearchState!(T, S)[S] state_pool;
        HistoryNode!(S) history = null;
        DefenseResult!T[DefenseState!T] defense_table;
        for (int i = min_depth; i <= max_depth; i++){
            calculate_minimax_value(state_pool, history, defense_table, i, lower_bound, upper_bound);
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

alias BaseSearchState8 = BaseSearchState!(Board8, State8);
alias SearchState8 = SearchState!(Board8, State8);


unittest
{
    State8 s = State8(rectangle8(2, 2));
    s.player = Board8(0, 0) | Board8(1, 1);
    DefenseResult8[DefenseState8] empty;
    SearchState8 ss = new SearchState8(s, Board8(), Board8(), Board8(), Board8(), empty);

    assert(ss.player_secure == ss.state.playing_area);
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
    assert(ss.children.length == 2);

    ss = new SearchState8(rectangle8(3, 2));
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == -6);
    assert(ss.upper_bound == 6);

    ss = new SearchState8(rectangle8(3, 3));
    ss.calculate_minimax_value(20);
    assert(ss.lower_bound == 9);
    assert(ss.upper_bound == 9);
    assert(ss.children.length == 4);
}

unittest
{
    SearchState8[State8] state_pool;
    DefenseResult8[DefenseState8] defense_table;
    auto ss = new SearchState8(rectangle8(4, 3));
    ss.make_children(state_pool, defense_table);
    assert(ss.children.length == 5);
}

version(all_tests)
{
    unittest
    {
        auto s = State8(rectangle8(4, 3));
        s.player = Board8(1, 2) | Board8(2, 2) | Board8(2, 1);
        s.opponent = rectangle8(4, 2) & ~Board8(2, 1) & ~Board8(3, 0);
        auto ss = new SearchState8(s);
        ss.calculate_minimax_value(20);
        assert(ss.lower_bound == -12);
        assert(ss.upper_bound == -10);


        s = State8(rectangle8(4, 3));
        s.player = rectangle8(3, 3).east & ~rectangle8(2, 2).east(2).south;
        s.opponent = rectangle8(4, 2).south & ~s.player & ~ Board8(3, 2);
        ss = new SearchState8(s);
        ss.calculate_minimax_value(20);
        assert(ss.lower_bound == 12);
        assert(ss.upper_bound == 12);


        s = State8(rectangle8(3, 4));
        s.player = Board8(0, 0) | Board8(1, 0);
        s.opponent = rectangle8(3, 3).south & ~(Board8(0, 2) | Board8(1, 2) | Board8(1, 3));
        ss = new SearchState8(s);
        ss.calculate_minimax_value(20);
        assert(ss.lower_bound == -12);
        assert(ss.upper_bound == -12);

    }
}