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
//import search_state;
import defense;


static bool is_better(T, S)(DefenseSearchState!(T, S) a, DefenseSearchState!(T, S) b){
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

    int a_immortal = a.state.opponent_immortal.popcount - a.state.player_immortal.popcount;
    int b_immortal = b.state.opponent_immortal.popcount - b.state.player_immortal.popcount;

    if (a_immortal > b_immortal){
        return true;
    }
    if (b_immortal > a_immortal){
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

    bool opBinaryRight(string op)(in T lhs) const pure nothrow
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


unittest
{
    auto s = DefenseState8();
    auto h = new HistoryNode!(DefenseState8)(s);

    auto child_s = s;
    child_s.player = Board8(3, 3);
    auto child_h = new HistoryNode!(DefenseState8)(child_s, h);

    assert(child_s !in h);
    assert(child_s in child_h);
    assert(s in child_h);
}


struct Transposition
{
    private
    {
        float _lower_bound = -float.infinity;
        float _upper_bound = float.infinity;
    }
    bool is_final = false;

    this(float lower_bound, float upper_bound)
    {
        _lower_bound = lower_bound;
        _upper_bound = upper_bound;
        is_final = lower_bound == upper_bound;
    }

    this(float lower_bound, float upper_bound, bool is_final)
    {
        _lower_bound = lower_bound;
        _upper_bound = upper_bound;
        this.is_final = _lower_bound == _upper_bound || is_final;
    }

    float lower_bound() const @property
    {
        return _lower_bound;
    }

    float upper_bound() const @property
    {
        return _upper_bound;
    }

    float lower_bound(float value) @property
    {
        _lower_bound = value;
        is_final = _lower_bound == _upper_bound || is_final;
        return _lower_bound;
    }

    float upper_bound(float value) @property
    {
        _upper_bound = value;
        is_final = _lower_bound == _upper_bound || is_final;
        return _upper_bound;
    }
}


class DefenseSearchState(T, S)
{
    S state;
    int value_shift;
    bool is_leaf;
    bool is_final;
    DefenseSearchState!(T, S)[] children;
    DefenseSearchState!(T, S)[S] parents;

    T player_useless;
    //T opponent_useless;

    Transposition[DefenseState!T] *defense_transposition_table;

    private
    {
        float _lower_bound = -float.infinity;
        float _upper_bound = float.infinity;
    }

    float lower_bound() const @property
    {
        return _lower_bound;
    }

    float upper_bound() const @property
    {
        return _upper_bound;
    }

    float lower_bound(float value) @property
    {
        _lower_bound = value;
        is_final = _lower_bound == _upper_bound || is_final;
        return _lower_bound;
    }

    float upper_bound(float value) @property
    {
        _upper_bound = value;
        is_final = _lower_bound == _upper_bound || is_final;
        return _upper_bound;
    }

    invariant
    {
        assert(state.black_to_play);
        assert(state.passes <= 2);
    }

    this(T playing_area, Transposition[DefenseState!T] *defense_transposition_table=null)
    {
        this(S(playing_area), 0, defense_transposition_table);
    }

    this (S state, int value_shift=0, Transposition[DefenseState!T] *defense_transposition_table=null){
        this.defense_transposition_table = defense_transposition_table;
        state.analyze_unconditional;
        this.state = state;
        T player_retainable;
        T opponent_retainable;
        if (defense_transposition_table !is null){
            analyze_local(player_retainable, opponent_retainable);
        }
        value_shift += this.state.reduce;
        this.value_shift = value_shift;
        this.state.canonize;
        if (state.is_leaf){
            is_leaf = true;
            lower_bound = upper_bound = state.liberty_score + value_shift;
        }
        else{
            update_bounds(player_retainable, opponent_retainable);
        }
    }

    void analyze_local(out T player_retainable, out T opponent_retainable)
    {
        T opponent_useless;
        DefenseState!T[] player_eyespaces;
        DefenseState!T[] opponent_eyespaces;

        extract_eyespaces!(T, S)(state, state.player_immortal, state.opponent_immortal, player_eyespaces, opponent_eyespaces);

        string analyze_eyespaces(string player, string opponent)
        {
            return "
                foreach (eyespace; " ~ player ~ "_eyespaces){
                    if (eyespace.playing_area.popcount < state.playing_area.popcount){
                        auto result = calculate_status!T(eyespace, defense_transposition_table);
                        if (result.status == Status.retainable || result.status == Status.defendable){
                            " ~ player ~ "_retainable |= eyespace.playing_area & ~state." ~ opponent ~ "_immortal;
                        }
                        else if (result.status == Status.secure){
                            state." ~ player ~ "_immortal |= eyespace.playing_area & ~state." ~ opponent ~ "_immortal;
                        }

                        " ~ player ~ "_useless |= result.player_useless;
                        " ~ opponent ~ "_useless |= result.opponent_useless;
                    }
                }
            ";
        }

        mixin(analyze_eyespaces("player", "opponent"));
        mixin(analyze_eyespaces("opponent", "player"));
    }

    void update_bounds(T player_retainable, T opponent_retainable){
        if (defense_transposition_table !is null && state in *defense_transposition_table){
            auto transposition = (*defense_transposition_table)[state];
            lower_bound = transposition.lower_bound + value_shift;
            upper_bound = transposition.upper_bound + value_shift;
            is_final = transposition.is_final;
        }
        else{
            float size = state.playing_area.popcount;
            if (!state.player_target){
                lower_bound = 2 * (state.player_immortal.popcount + player_retainable.popcount) - size + value_shift;
            }
            if (!state.opponent_target){
                upper_bound = -(2 * (state.opponent_immortal.popcount + opponent_retainable.popcount) - size) + value_shift;
            }
        }
    }

    T[] effective_moves()
    {
        T[] moves;
        for (int y = 0; y < T.HEIGHT; y++){
            for (int x = 0; x < T.WIDTH; x++){
                T move = T(x, y);
                if (move & state.playing_area & ~player_useless){
                    moves ~= move;
                }
            }
        }
        moves ~= T.init;
        return moves;
    }

    void make_children(ref DefenseSearchState!(T, S)[S] state_pool)
    {
        children = [];
        auto child_states = state.children(effective_moves);

        foreach (child_state; child_states){
            child_state.black_to_play = true;
            auto child = new DefenseSearchState!(T, S)(child_state, -value_shift, defense_transposition_table);
            children ~= child;
        }

        DefenseSearchState!(T, S)[] unique_children;
        bool[S] seen;
        foreach (child; children){
            if (child.state !in seen){
                seen[child.state] = true;
                unique_children ~= child;
            }
        }

        children = [];
        foreach (child; unique_children){
            if (child.state in state_pool && state_pool[child.state].value_shift == child.value_shift){
                auto pool_child = state_pool[child.state];
                children ~= pool_child;
                pool_child.parents[state] = this;
            }
            else{
                children ~= child;
                child.parents[state] = this;
                state_pool[child.state] = child;
            }
        }

        children.randomShuffle;

        sort!(is_better!(T, S))(children);

    }

    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        DefenseSearchState!(T, S)[] queue;
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

        if (is_final){
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

            child.calculate_minimax_value(state_pool, my_history, depth - 1, -beta, -alpha);

            changed = update_value; // TODO: Do single updates.
            if (changed){
                //update_parents;
            }
        }

        if (depth == float.infinity){
            // No alpha-beta break with an unlimited search means that this state was searched thoroughly.
            is_final = true;
            if (defense_transposition_table !is null){
                (*defense_transposition_table)[state] = Transposition(lower_bound - value_shift, upper_bound - value_shift, is_final);
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


    bool update_value()
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

        bool changed = old_lower_bound != lower_bound || old_upper_bound != upper_bound;

        if (changed && defense_transposition_table !is null){
            if (state in *defense_transposition_table){
                auto transposition = (*defense_transposition_table)[state];
                if (transposition.lower_bound + value_shift < lower_bound){
                    transposition.lower_bound = lower_bound - value_shift;
                }
                if (transposition.upper_bound + value_shift < upper_bound){
                    transposition.upper_bound = upper_bound - value_shift;
                }
            }
            else{
                (*defense_transposition_table)[state] = Transposition(lower_bound - value_shift, upper_bound - value_shift);
            }
        }

        return changed;
    }

    DefenseSearchState!(T, S)[] principal_path(string type)(int max_depth=100)
    {
        static assert(type == "lower" || type == "upper");
        static if (type == "lower"){
            enum other_type = "upper";
        }
        else{
            enum other_type = "lower";
        }
        if (max_depth <= 0){
            return [];
        }
        DefenseSearchState!(T, S)[] result = [this];
        bool found_one = false;
        foreach(child; children){
            if (mixin("-child." ~ other_type ~ "_bound == " ~ type ~ "_bound && -child." ~ type ~ "_bound == " ~ other_type ~ "_bound")){
                result ~= child.principal_path!type(max_depth - 1);
                found_one = true;
                break;
            }
        }

        if (!found_one){
            foreach(child; children){
                if (mixin("-child." ~ other_type ~ "_bound == " ~ type ~ "_bound")){
                    result ~= child.principal_path!type(max_depth - 1);
                    break;
                }
            }
        }

        return result;
    }

    override string toString()
    {
        return format(
            "%s\nlower bound=%s upper bound=%s value shift=%s leaf=%s number of children=%s",
            state,
            lower_bound,
            upper_bound,
            value_shift,
            is_leaf,
            children.length
        );
    }
}


alias DefenseSearchState8 = DefenseSearchState!(Board8, DefenseState8);

void ppp(DefenseSearchState8 dss, int max_depth=20)
{
    foreach (p; dss.principal_path!"upper"(max_depth)){
        writeln(p);
    }
}

void pc(DefenseSearchState8 dss)
{
    foreach (c; dss.children){
        writeln(c);
    }
}

unittest
{
    Transposition[DefenseState8] empty;
    auto defense_transposition_table = &empty;

    auto ss = new DefenseSearchState8(rectangle8(1, 1), defense_transposition_table);
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 0);
    assert(ss.upper_bound == 0);

    ss = new DefenseSearchState8(rectangle8(2, 1), defense_transposition_table);
    ss.calculate_minimax_value;
    assert(ss.lower_bound == -2);
    assert(ss.upper_bound == 2);

    ss = new DefenseSearchState8(rectangle8(3, 1), defense_transposition_table);
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 3);
    assert(ss.upper_bound == 3);

    ss = new DefenseSearchState8(rectangle8(4, 1), defense_transposition_table);
    ss.calculate_minimax_value;
    assert(ss.lower_bound == 4);
    assert(ss.upper_bound == 4);

    ss = new DefenseSearchState8(rectangle8(2, 2), defense_transposition_table);
    ss.calculate_minimax_value(8);
    assert(ss.lower_bound == -4);
    assert(ss.upper_bound == 4);

    ss = new DefenseSearchState8(rectangle8(3, 2), defense_transposition_table);
    ss.calculate_minimax_value(9);
    assert(ss.lower_bound == -6);
    assert(ss.upper_bound == 6);


    auto s = DefenseState8(rectangle8(3, 2));
    s.player = Board8(0, 0) | Board8(1, 0) | Board8(2, 0);
    s.player_target = s.player;
    auto ds = new DefenseSearchState8(s, 0, defense_transposition_table);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == 6);
    assert(ds.upper_bound == 6);

    s = DefenseState8(rectangle8(3, 2));
    s.opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0);
    s.opponent_target = s.opponent;
    ds = new DefenseSearchState8(s, 0, defense_transposition_table);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);

    s = DefenseState8(rectangle8(4, 2));
    s.opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0) | Board8(3, 0);
    s.opponent_target = s.opponent;
    ds = new DefenseSearchState8(s, 0, defense_transposition_table);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == -8);
    assert(ds.upper_bound == -8);

    //Rectangular six in the corner with no outside liberties and infinite ko threats.
    s = DefenseState8();
    s.opponent = rectangle8(4, 3) & ~rectangle8(3, 2);
    s.opponent_target = s.opponent;
    s.player = rectangle8(5, 4) & ~rectangle8(4, 3);
    s.player_immortal = s.player;
    s.playing_area = rectangle8(5, 4);
    s.ko_threats = -float.infinity;
    ds = new DefenseSearchState8(s, 0, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.lower_bound == float.infinity);

    // Rectangular six in the corner with one physical outside liberty and no ko threats.
    s.player_immortal &= ~Board8(4, 0);
    s.player &= ~Board8(4, 0);
    s.ko_threats = 0;
    ds = new DefenseSearchState8(s, 0, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);

    // Rectangular six in the corner with one physical outside liberty and one ko threat.
    s.ko_threats = -1;
    ds = new DefenseSearchState8(s, 0, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == -4);
    assert(ds.upper_bound == -4);

    // Rectangular six in the corner with two physical outside liberties and infinite ko threats for the invader.
    s.player &= ~Board8(4, 1);
    s.player_immortal &= ~Board8(4, 1);
    s.ko_threats = float.infinity;
    ds = new DefenseSearchState8(s, 0, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == -4);
    assert(ds.upper_bound == -4);


    //Rectangular six in the corner with no outside liberties and infinite ko threats.
    s = DefenseState8();
    s.opponent = rectangle8(4, 3) & ~rectangle8(3, 2);
    s.opponent_target = s.opponent;
    s.player = rectangle8(5, 4) & ~rectangle8(4, 3);
    s.player_immortal = s.player;
    s.playing_area = rectangle8(5, 4);
    s.ko_threats = -float.infinity;
    ds = new DefenseSearchState8(s, 0, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.lower_bound == float.infinity);

    // Rectangular six in the corner with one outside liberty and no ko threats.
    s.opponent_outside_liberties = 1;
    s.ko_threats = 0;
    ds = new DefenseSearchState8(s, 0, defense_transposition_table);
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
    s.opponent_outside_liberties = 2;
    s.ko_threats = float.infinity;
    ds = new DefenseSearchState8(s, 0, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == -4);
    assert(ds.upper_bound == -4);


    // Test a state where the opponent can forfeit her stones.
    auto opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0);
    auto space = Board8(0, 1) | Board8(1, 1) | Board8(2, 1) | Board8(1, 2);
    s = DefenseState8();
    s.playing_area = space | opponent;
    s.opponent = opponent;
    s.opponent_target = opponent;

    ds = new DefenseSearchState8(s, 0, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);
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
