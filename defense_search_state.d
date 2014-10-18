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


static bool is_better(T)(DefenseSearchState!T a, DefenseSearchState!T b){
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

    int a_immortal = a.state.opponent_immortal.popcount - a.state.player_immortal.popcount - a.state.value_shift;
    int b_immortal = b.state.opponent_immortal.popcount - b.state.player_immortal.popcount - b.state.value_shift;

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

    int a_popcount = a.state.opponent.popcount - a.state.player.popcount - a.state.value_shift;
    int b_popcount = b.state.opponent.popcount - b.state.player.popcount - b.state.value_shift ;

    if (a_popcount > b_popcount){
        return true;
    }
    if (b_popcount > a_popcount){
        return false;
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
        this.is_final = (_lower_bound == _upper_bound) || is_final;
    }

    float lower_bound() const @property
    {
        return _lower_bound;
    }

    float upper_bound() const @property
    {
        return _upper_bound;
    }

    void set_bounds(float lower_bound, float upper_bound)
    {
        _lower_bound = lower_bound;
        _upper_bound = upper_bound;
        is_final = lower_bound == upper_bound || is_final;
    }
}


class DefenseSearchState(T)
{
    CanonicalDefenseState!T state;
    bool is_leaf;
    bool is_final;
    DefenseSearchState!T[] children;
    DefenseSearchState!T[CanonicalDefenseState!T] parents;

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

    void set_bounds(float lower_bound, float upper_bound)
    {
        _lower_bound = lower_bound;
        _upper_bound = upper_bound;
        is_final = lower_bound == upper_bound || is_final;
    }


    invariant
    {
        assert(state.passes <= 2);
    }

    this(T playing_area, Transposition[DefenseState!T] *defense_transposition_table=null)
    {
        this(CanonicalDefenseState!T(playing_area), defense_transposition_table);
    }

    this(DefenseState!T state, Transposition[DefenseState!T] *defense_transposition_table=null)
    {
        this(CanonicalDefenseState!T(state), defense_transposition_table);
    }

    this (CanonicalDefenseState!T state, Transposition[DefenseState!T] *defense_transposition_table=null){
        this.defense_transposition_table = defense_transposition_table;
        this.state = state;
        T player_retainable;
        T opponent_retainable;
        if (defense_transposition_table !is null && state.playing_area.popcount >= 10){
            analyze_local(player_retainable, opponent_retainable);
        }
        if (state.is_leaf){
            is_leaf = true;
            float value = liberty_score(player_retainable, opponent_retainable);
            set_bounds(value, value);
        }
        else{
            update_bounds(player_retainable, opponent_retainable);
        }
    }

    float liberty_score(T player_retainable, T opponent_retainable)
    {
        float score = state.target_score;

        if (score == 0){
            auto player_controlled_terrirory = (state.player | player_retainable| state.player_immortal) & ~(opponent_retainable | state.opponent_immortal);
            auto opponent_controlled_terrirory = (state.opponent | opponent_retainable | state.opponent_immortal) & ~(player_retainable | state.player_immortal);

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

    void analyze_local(out T player_retainable, out T opponent_retainable)
    {
        T opponent_useless;
        DefenseState!T[] player_eyespaces;
        DefenseState!T[] opponent_eyespaces;

        extract_eyespaces!(T, CanonicalDefenseState!T)(state, state.player_immortal, state.opponent_immortal, player_eyespaces, opponent_eyespaces);

        string analyze_eyespaces(string player, string opponent)
        {
            return "
                foreach (eyespace; " ~ player ~ "_eyespaces){
                    if (eyespace.playing_area.popcount < state.playing_area.popcount){
                        auto result = calculate_status!T(eyespace, defense_transposition_table);
                        if (result.status == Status.retainable){
                            " ~ player ~ "_retainable |= eyespace.playing_area & ~state." ~ opponent ~ "_immortal;
                            if (!state.ko){
                                " ~ opponent ~ "_useless |= eyespace.playing_area;
                            }
                        }
                        if (result.status == Status.defendable){
                            " ~ player ~ "_retainable |= eyespace.playing_area & ~state." ~ opponent ~ "_immortal;
                            " ~ player ~ "_useless |= eyespace.playing_area;
                            if (!state.ko){
                                " ~ opponent ~ "_useless |= eyespace.playing_area;
                            }

                        }
                        else if (result.status == Status.secure){
                            state." ~ player ~ "_immortal |= eyespace.playing_area & ~state." ~ opponent ~ "_immortal;
                        }

                        //" ~ player ~ "_useless |= result.player_useless;
                        //" ~ opponent ~ "_useless |= result.opponent_useless;
                    }
                }
            ";
        }

        mixin(analyze_eyespaces("player", "opponent"));
        mixin(analyze_eyespaces("opponent", "player"));
    }

    void update_bounds(T player_retainable, T opponent_retainable){
        if (defense_transposition_table !is null && state.state in *defense_transposition_table){
            auto transposition = (*defense_transposition_table)[state.state];
            set_bounds(transposition.lower_bound + state.value_shift, transposition.upper_bound + state.value_shift);
            is_final = transposition.is_final;
        }
        else{
            float size = state.playing_area.popcount;
            if (!state.player_target){
                _lower_bound = 2 * (state.player_immortal.popcount + player_retainable.popcount) - size + state.value_shift;
            }
            if (!state.opponent_target){
                _upper_bound = -(2 * (state.opponent_immortal.popcount + opponent_retainable.popcount) - size) + state.value_shift;
            }
            set_bounds(_lower_bound, _upper_bound);
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
        moves ~= T();
        return moves;
    }

    void make_children(ref DefenseSearchState!T[CanonicalDefenseState!T] state_pool)
    {
        children = [];
        auto child_states = state.children(effective_moves);

        foreach (child_state; child_states){
            if (child_state in state_pool){
                auto pool_child = state_pool[child_state];
                children ~= pool_child;
                pool_child.parents[state] = this;
            }
            else{
                auto child = new DefenseSearchState!T(child_state, defense_transposition_table);
                children ~= child;
                child.parents[state] = this;
                state_pool[child_state] = child;
            }
        }

        children.randomShuffle;

        sort!(is_better!T)(children);

    }

    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        DefenseSearchState!T[] queue;
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
        ref DefenseSearchState!T[CanonicalDefenseState!T] state_pool,
        ref HistoryNode!(CanonicalDefenseState!T) history,
        float depth=float.infinity,
        float alpha=-float.infinity,
        float beta=float.infinity
    )
    {
        bool full_search = depth == float.infinity && alpha == -float.infinity && beta == float.infinity;
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

        auto my_history = new HistoryNode!(CanonicalDefenseState!T)(state, history);

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

        if (full_search){
            is_final = true;
            if (defense_transposition_table !is null){
                (*defense_transposition_table)[state.state] = Transposition(lower_bound - state.value_shift, upper_bound - state.value_shift, is_final);
            }
        }
    }

    void calculate_minimax_value(float depth=float.infinity)
    {

        DefenseSearchState!T[CanonicalDefenseState!T] state_pool;
        HistoryNode!(CanonicalDefenseState!T) history = null;
        calculate_minimax_value(state_pool, history, depth, -float.infinity, float.infinity);
    }

    void iterative_deepening_search(int min_depth, int max_depth)
    {
        DefenseSearchState!T[CanonicalDefenseState!T] state_pool;
        HistoryNode!(CanonicalDefenseState!T) history = null;
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
        if (is_final){
            // There should be nothing left to do here.
            return false;
        }

        float old_lower_bound = lower_bound;
        float old_upper_bound = upper_bound;

        float new_lower_bound = -float.infinity;
        float new_upper_bound = -float.infinity;

        foreach (child; children){
            if (-child.upper_bound > new_lower_bound){
                new_lower_bound = -child.upper_bound;
            }
            if (-child.lower_bound > new_upper_bound){
                new_upper_bound = -child.lower_bound;
            }
        }

        set_bounds(new_lower_bound, new_upper_bound);
        bool changed = old_lower_bound != lower_bound || old_upper_bound != upper_bound;

        if (changed && defense_transposition_table !is null){
            if (state.state in *defense_transposition_table){
                auto transposition = (*defense_transposition_table)[state.state];
                float transposition_lower_bound = transposition.lower_bound;
                if (transposition_lower_bound + state.value_shift < lower_bound){
                    transposition_lower_bound = lower_bound - state.value_shift;
                }
                float transposition_upper_bound = transposition.upper_bound;
                if (transposition_upper_bound + state.value_shift < upper_bound){
                    transposition_upper_bound = upper_bound - state.value_shift;
                }
                transposition.set_bounds(transposition_lower_bound, transposition_upper_bound);
            }
            else{
                (*defense_transposition_table)[state.state] = Transposition(lower_bound - state.value_shift, upper_bound - state.value_shift);
            }
        }

        return changed;
    }

    DefenseSearchState!T[] principal_path(string type)(int max_depth=100)
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
        DefenseSearchState!T[] result = [this];
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
            "%s\nlower bound=%s upper bound=%s leaf=%s final=%s, number of children=%s",
            state,
            lower_bound,
            upper_bound,
            is_leaf,
            is_final,
            children.length
        );
    }
}


alias DefenseSearchState8 = DefenseSearchState!Board8;

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
    auto ds = new DefenseSearchState8(s, defense_transposition_table);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == 6);
    assert(ds.upper_bound == 6);

    s = DefenseState8(rectangle8(3, 2));
    s.opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0);
    s.opponent_target = s.opponent;
    ds = new DefenseSearchState8(s, defense_transposition_table);

    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);

    s = DefenseState8(rectangle8(4, 2));
    s.opponent = Board8(0, 0) | Board8(1, 0) | Board8(2, 0) | Board8(3, 0);
    s.opponent_target = s.opponent;
    ds = new DefenseSearchState8(s, defense_transposition_table);

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
    ds = new DefenseSearchState8(s, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.lower_bound == float.infinity);

    // Rectangular six in the corner with one physical outside liberty and no ko threats.
    s.player_immortal &= ~Board8(4, 0);
    s.player &= ~Board8(4, 0);
    s.ko_threats = 0;
    ds = new DefenseSearchState8(s, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);

    // Rectangular six in the corner with one physical outside liberty and one ko threat.
    s.ko_threats = -1;
    ds = new DefenseSearchState8(s, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == -4);
    assert(ds.upper_bound == -4);

    // Rectangular six in the corner with two physical outside liberties and infinite ko threats for the invader.
    s.player &= ~Board8(4, 1);
    s.player_immortal &= ~Board8(4, 1);
    s.ko_threats = float.infinity;
    ds = new DefenseSearchState8(s, defense_transposition_table);
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
    ds = new DefenseSearchState8(s, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.lower_bound == float.infinity);

    // Rectangular six in the corner with one outside liberty and no ko threats.
    s.opponent_outside_liberties = 1;
    s.ko_threats = 0;
    ds = new DefenseSearchState8(s, defense_transposition_table);
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
    ds = new DefenseSearchState8(s, defense_transposition_table);
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

    ds = new DefenseSearchState8(s, defense_transposition_table);
    ds.calculate_minimax_value;
    assert(ds.lower_bound == float.infinity);
    assert(ds.upper_bound == float.infinity);

    ds = new DefenseSearchState8(rectangle8(3, 3), defense_transposition_table);
    ds.calculate_minimax_value(12);
    assert(ds.lower_bound == 9);
    assert(ds.upper_bound == 9);
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
