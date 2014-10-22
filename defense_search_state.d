module defense_search_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import polyomino;
import board8;
import state;
import defense_state;
//import search_state;
import defense;
import heuristic;


static bool is_better(T, C)(DefenseSearchState!(T, C) a, DefenseSearchState!(T, C) b){
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

    T player_secure;
    T opponent_secure;
    a.get_secure_areas(player_secure, opponent_secure);
    int a_secure = opponent_secure.popcount - player_secure.popcount - a.state.value_shift;
    b.get_secure_areas(player_secure, opponent_secure);
    int b_secure = opponent_secure.popcount - player_secure.popcount - b.state.value_shift;

    if (a_secure > b_secure){
        return true;
    }
    if (b_secure > a_secure){
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
        if (lower_bound > _lower_bound){
            _lower_bound = lower_bound;
        }
        if (upper_bound < _upper_bound){
            _upper_bound = upper_bound;
        }
        is_final = _lower_bound == _upper_bound || is_final;
    }
}


class DefenseSearchState(T, C)
{
    C state;
    bool is_leaf;
    bool is_final;
    DefenseSearchState!(T, C)[] children;
    DefenseSearchState!(T, C)[C] parents;

    T player_useless;
    //T opponent_useless;

    Transposition[DefenseState!T] *defense_transposition_table;
    bool do_local_analysis = true;

    static if (is (C == CanonicalState!T)){
        T player_secure;
        T opponent_secure;
    }

    float heuristic_value;
    float last_heuristic_value;

    private
    {
        float _lower_bound = -float.infinity;
        float _upper_bound = float.infinity;
        float _heuristic_lower_bound = -float.infinity;
        float _heuristic_upper_bound = float.infinity;
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
        if (lower_bound > _lower_bound){
            _lower_bound = lower_bound;
        }
        if (upper_bound < _upper_bound){
            _upper_bound = upper_bound;
        }
        is_final = _lower_bound == _upper_bound || is_final;
    }

    float heuristic_lower_bound() const @property
    {
        return _heuristic_lower_bound;
    }

    float heuristic_upper_bound() const @property
    {
        return _heuristic_upper_bound;
    }

    float heuristic_lower_bound(float value) @property
    {
        if (value > _heuristic_lower_bound){
            _heuristic_lower_bound = value;
        }
        if (_heuristic_lower_bound < _lower_bound){
            _heuristic_lower_bound = _lower_bound;
        }
        else if (_heuristic_lower_bound > _upper_bound){
            _heuristic_lower_bound = _upper_bound;
        }
        return value;
    }

    float heuristic_upper_bound(float value) @property
    {
        if (value < _heuristic_upper_bound){
            _heuristic_upper_bound = value;
        }
        if (_heuristic_upper_bound > _upper_bound){
            _heuristic_upper_bound = _upper_bound;
        }
        else if (_heuristic_upper_bound < _lower_bound){
            _heuristic_upper_bound = _lower_bound;
        }
        return value;
    }

    void reset_heuristic_values()
    {
        _heuristic_lower_bound = -float.infinity;
        _heuristic_upper_bound = float.infinity;
        heuristic_lower_bound = _heuristic_lower_bound;
        heuristic_upper_bound = _heuristic_upper_bound;
    }

    invariant
    {
        assert(state.passes <= 2);
    }

    this(T playing_area, Transposition[DefenseState!T] *defense_transposition_table=null, bool do_local_analysis=true)
    {
        this(C(playing_area), defense_transposition_table, do_local_analysis);
    }

    static if (is (C == CanonicalDefenseState!T)){
        this(DefenseState!T state, Transposition[DefenseState!T] *defense_transposition_table=null, bool do_local_analysis=true)
        {
            this(C(state), defense_transposition_table, do_local_analysis);
        }
    }
    else static if (is (C == CanonicalState!T)){
        this(State!T state, Transposition[DefenseState!T] *defense_transposition_table=null, bool do_local_analysis=true)
        {
            this(C(state), defense_transposition_table, do_local_analysis);
        }
    }
    else{
        static assert(false);
    }

    this (C state, Transposition[DefenseState!T] *defense_transposition_table=null, bool do_local_analysis=true){
        this.state = state;
        this.defense_transposition_table = defense_transposition_table;
        this.do_local_analysis = do_local_analysis;

        static if (is (C == CanonicalState!T)){
            state.analyze_unconditional(player_secure, opponent_secure);
        }

        T player_retainable;
        T opponent_retainable;
        if (defense_transposition_table !is null && do_local_analysis){
            analyze_local(player_retainable, opponent_retainable);
        }
        if (state.is_leaf){
            is_leaf = true;
            float value = score(player_retainable, opponent_retainable);
            set_bounds(value, value);
            heuristic_lower_bound = heuristic_upper_bound = value;
        }
        else{
            update_bounds(player_retainable, opponent_retainable);

            T player_secure;
            T opponent_secure;
            get_secure_areas(player_secure, opponent_secure);
            last_heuristic_value = this.heuristic_value = heuristic_lower_bound = heuristic_upper_bound = heuristic.heuristic_value!T(
                state.playing_area,
                state.player | player_retainable | player_secure ,
                state.opponent | opponent_retainable | opponent_secure
            );
        }
    }

    float score(T player_retainable, T opponent_retainable)
    {
        static if (is (C == CanonicalDefenseState!T)){
            return controlled_liberty_score(player_retainable, opponent_retainable, state.player_immortal, state.opponent_immortal);
        }
        else static if (is (C == CanonicalState!T)){
            return controlled_liberty_score(player_retainable, opponent_retainable, player_secure, opponent_secure);
        }
    }

    float controlled_liberty_score(T player_retainable, T opponent_retainable, T player_secure, T opponent_secure)
    in
    {
        assert(state.black_to_play);
    }
    body
    {
        float score = state.target_score;

        if (score == 0){
            auto player_controlled_terrirory = (state.player | player_retainable| player_secure) & ~(opponent_retainable | opponent_secure);
            auto opponent_controlled_terrirory = (state.opponent | opponent_retainable | opponent_secure) & ~(player_retainable | player_secure);

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

    void get_secure_areas(out T player_secure, out T opponent_secure)
    {
        static if (is (C == CanonicalDefenseState!T)){
            player_secure = state.player_immortal;
            opponent_secure = state.opponent_immortal;
        }
        else static if (is (C == CanonicalState!T)){
            player_secure = this.player_secure;
            opponent_secure = this.opponent_secure;
        }
    }

    void set_secure_areas(in T player_secure, in T opponent_secure)
    {
        static if (is (C == CanonicalDefenseState!T)){
            state.player_immortal = player_secure;
            state.opponent_immortal = opponent_secure;
        }
        else static if (is (C == CanonicalState!T)){
            this.player_secure = player_secure;
            this.opponent_secure = opponent_secure;
        }
    }

    void analyze_local(out T player_retainable, out T opponent_retainable)
    {
        T opponent_useless;
        DefenseState!T[] player_eyespaces;
        DefenseState!T[] opponent_eyespaces;

        T player_secure;
        T opponent_secure;
        get_secure_areas(player_secure, opponent_secure);

        extract_eyespaces!(T, C)(state, player_secure, opponent_secure, player_eyespaces, opponent_eyespaces);

        string analyze_eyespaces(string player, string opponent)
        {
            return "
                foreach (eyespace; " ~ player ~ "_eyespaces){
                    if (eyespace.playing_area.popcount < state.playing_area.popcount){
                        auto result = calculate_status!T(eyespace, defense_transposition_table);
                        if (result.status == Status.retainable){
                            " ~ player ~ "_retainable |= eyespace.playing_area & ~" ~ opponent ~ "_secure;
                            if (!state.ko){
                                " ~ opponent ~ "_useless |= eyespace.playing_area;
                            }
                        }
                        if (result.status == Status.defendable){
                            " ~ player ~ "_retainable |= eyespace.playing_area & ~" ~ opponent ~ "_secure;
                            " ~ player ~ "_useless |= eyespace.playing_area;
                            if (!state.ko){
                                " ~ opponent ~ "_useless |= eyespace.playing_area;
                            }

                        }
                        else if (result.status == Status.secure){
                            " ~ player ~ "_secure |= eyespace.playing_area & ~" ~ opponent ~ "_secure;
                        }

                        //" ~ player ~ "_useless |= result.player_useless;
                        //" ~ opponent ~ "_useless |= result.opponent_useless;
                    }
                }
            ";
        }

        mixin(analyze_eyespaces("player", "opponent"));
        mixin(analyze_eyespaces("opponent", "player"));

        set_secure_areas(player_secure, opponent_secure);
    }

    void update_bounds(T player_retainable, T opponent_retainable){
        static if (is (C == CanonicalDefenseState!T)){
            if (defense_transposition_table !is null && state.state in *defense_transposition_table){
                auto transposition = (*defense_transposition_table)[state.state];
                set_bounds(transposition.lower_bound + state.value_shift, transposition.upper_bound + state.value_shift);
                is_final = transposition.is_final;
            }
            else{
                float size = state.playing_area.popcount;
                float lower_bound, upper_bound;
                if (!state.player_target){
                    lower_bound = 2 * (state.player_immortal | player_retainable).popcount - size + state.value_shift;
                }
                if (!state.opponent_target){
                    upper_bound = -(2 * (state.opponent_immortal | opponent_retainable).popcount - size) + state.value_shift;
                }
                set_bounds(lower_bound, upper_bound);
            }
        }
        else{
            float size = state.playing_area.popcount;

            float lower_bound = 2 * (player_secure | player_retainable).popcount - size;
            float upper_bound = -(2 * (opponent_secure | opponent_retainable).popcount - size);

            set_bounds(lower_bound, upper_bound);
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

    void make_children(ref DefenseSearchState!(T, C)[C] state_pool)
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
                auto child = new DefenseSearchState!(T, C)(child_state, defense_transposition_table, do_local_analysis);
                children ~= child;
                child.parents[state] = this;
                state_pool[child_state] = child;
            }
        }

        children.randomShuffle;
    }

    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        DefenseSearchState!(T, C)[] queue;
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

    /*
    void reset_heuristics()
    {
        DefenseSearchState!(T, C)[] queue;
        queue ~= this;

        bool[C] seen;
        seen[state] = true;

        while(queue.length){
            auto search_state = queue.front;
            queue.popFront;
            search_state.heuristic_lower_bound = -float.infinity;
            search_state.heuristic_upper_bound = float.infinity;
            foreach (child; search_state.children){
                if (child.state !in seen){
                    queue ~= child;
                    seen[child.state] = true;
                }
            }
        }
    }
    */

    void reset_heuristics(ref DefenseSearchState!(T, C)[C] state_pool)
    {
        foreach (ref search_state; state_pool.byValue){
            search_state.reset_heuristic_values;
        }
    }

    void calculate_minimax_value(
        ref DefenseSearchState!(T, C)[C] state_pool,
        ref HistoryNode!(C) history,
        float depth=float.infinity,
        float alpha=-float.infinity,
        float beta=float.infinity
    )
    {
        bool full_search = depth == float.infinity && alpha == -float.infinity && beta == float.infinity;
        if (is_leaf || is_final || depth <= 0){
            return;
        }

        if (history !is null && state in history){
            // Do a short search instead?
            return;
        }

        auto my_history = new HistoryNode!(C)(state, history);

        if (!children.length){
            make_children(state_pool);
        }

        static bool by_heuristic_value(DefenseSearchState!(T, C) a, DefenseSearchState!(T, C) b){
            /*
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
            */
            return a.last_heuristic_value < b.last_heuristic_value;
        }

        sort!by_heuristic_value(children);

        // Check for leaves and transpositions.
        bool changed = update_value(depth > 1);
        if (changed){
            //update_parents;
        }

        foreach (child; children){
            if (heuristic_lower_bound > alpha){
                alpha = heuristic_lower_bound;
            }
            if (heuristic_upper_bound < beta){
                beta = heuristic_upper_bound;
            }

            if (beta <= alpha){
                last_heuristic_value = heuristic_lower_bound;
                return;
            }

            child.calculate_minimax_value(state_pool, my_history, depth - 1, -beta, -alpha);

            changed = update_value(depth > 1); // TODO: Do single updates.
            if (changed){
                //update_parents;
            }
        }

        if (full_search){
            is_final = true;
            static if (is (C == CanonicalDefenseState!T)){
                if (defense_transposition_table !is null){
                    (*defense_transposition_table)[state.state] = Transposition(lower_bound - state.value_shift, upper_bound - state.value_shift, is_final);
                }
            }
        }

        last_heuristic_value = heuristic_lower_bound;
    }

    void calculate_minimax_value(float depth=float.infinity)
    {

        DefenseSearchState!(T, C)[C] state_pool;
        state_pool[state] = this;
        HistoryNode!(C) history = null;
        reset_heuristics(state_pool);
        calculate_minimax_value(state_pool, history, depth, -float.infinity, float.infinity);
    }

    void iterative_deepening(int min_depth, int max_depth)
    {
        DefenseSearchState!(T, C)[C] state_pool;
        state_pool[state] = this;
        HistoryNode!(C) history = null;
        for (int i = min_depth; i <= max_depth; i++){
            reset_heuristics(state_pool);
            calculate_minimax_value(state_pool, history, i, lower_bound, upper_bound);
            debug (iterative_deepening){
                writeln("Depth=", i);
                writeln(this);
                //writeln("Children:");
                //this.pc;
            }
        }
    }


    bool update_value(bool use_heuristic_bounds=true)
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

        if (children.length){
            float new_lower_bound = -float.infinity;
            float new_upper_bound = -float.infinity;

            float new_heuristic_lower_bound = -float.infinity;
            float new_heuristic_upper_bound = -float.infinity;

            foreach (child; children){
                if (-child.upper_bound > new_lower_bound){
                    new_lower_bound = -child.upper_bound;
                }
                if (-child.lower_bound > new_upper_bound){
                    new_upper_bound = -child.lower_bound;
                }
                if (use_heuristic_bounds){
                    if (-child.heuristic_upper_bound > new_heuristic_lower_bound){
                        new_heuristic_lower_bound = -child.heuristic_upper_bound;
                    }
                    if (-child.heuristic_lower_bound > new_heuristic_upper_bound){
                        new_heuristic_upper_bound = -child.heuristic_lower_bound;
                    }
                }
                else{
                    if (-child.heuristic_value > new_heuristic_lower_bound){
                        new_heuristic_lower_bound = -child.heuristic_value;
                    }
                    if (-child.heuristic_value > new_heuristic_upper_bound){
                        new_heuristic_upper_bound = -child.heuristic_value;
                    }
                }
            }

            set_bounds(new_lower_bound, new_upper_bound);

            heuristic_lower_bound = new_heuristic_lower_bound;
            heuristic_upper_bound = new_heuristic_upper_bound;
        }

        bool changed = old_lower_bound != lower_bound || old_upper_bound != upper_bound;

        static if (is (C == CanonicalDefenseState!T)){
            if (changed && defense_transposition_table !is null){
                if (state.state in *defense_transposition_table){
                    auto transposition = (*defense_transposition_table)[state.state];
                    transposition.set_bounds(lower_bound - state.value_shift, upper_bound - state.value_shift);
                    (*defense_transposition_table)[state.state] = transposition;
                }
                else{
                    (*defense_transposition_table)[state.state] = Transposition(lower_bound - state.value_shift, upper_bound - state.value_shift);
                }
            }
        }

        return changed;
    }

    DefenseSearchState!(T, C)[] principal_path(string type)(int max_depth=100)
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
        DefenseSearchState!(T, C)[] result = [this];
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
            "%s\nlower bound=%s upper bound=%s leaf=%s final=%s, number of children=%s\nheuristics: lower bound=%s upper bound=%s initial=%s",
            state,
            lower_bound,
            upper_bound,
            is_leaf,
            is_final,
            children.length,
            heuristic_lower_bound,
            heuristic_upper_bound,
            this.heuristic_value
        );
    }
}

alias SearchState8 = DefenseSearchState!(Board8, CanonicalState!Board8);

alias DefenseSearchState8 = DefenseSearchState!(Board8, CanonicalDefenseState!Board8);

void ppp(DefenseSearchState8 dss, int max_depth=20)
{
    foreach (p; dss.principal_path!"upper"(max_depth)){
        writeln(p);
    }
}

void pc(T)(T dss)
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
