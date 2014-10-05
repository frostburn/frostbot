module gamestate;

import std.stdio;
import std.string;
import std.algorithm;

import board8;
import state;


debug(minimax) static size_t pool_size;

class GameState(T)
{
    State!T state;
    float low_value = -float.infinity;
    float high_value = float.infinity;
    bool is_leaf;
    GameState!T[] children;
    GameState!T[] parents;

    public
    {
        T[] moves;
        State!T canonical_state;
        bool canonical_state_available = false;
        bool populated = false;
    }

    this(T playing_area)
    {
        state = State!T(playing_area);
        calculate_available_moves();
    }

    this(State!T state, T[] moves=null)
    {
        this.state = state;
        if (state.passes >= 2){
            is_leaf = true;
            update_value;
        }
        else{
            if (moves){
                this.moves = moves;
            }
            else{
                calculate_available_moves();
            }
        }
    }

    invariant
    {
        assert(state.passes <= 2);
    }

    GameState!T copy(){
        return new GameState!T(state);
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
    }

    void make_children(ref GameState!T[State!T] state_pool)
    {
        auto state_children = state.children(moves);
        children = [];
        foreach (child_state; state_children){
            if (child_state in state_pool){
                auto child = state_pool[child_state];
                bool parent_in_parents = false;
                foreach(parent; child.parents){
                    if (this is parent){
                        parent_in_parents = true;
                        break;
                    }
                }
                if (!parent_in_parents){
                    child.parents ~= this;
                }
                children ~= child;
            }
            else{
                auto child = new GameState!T(child_state, moves);
                child.parents ~= this;
                state_pool[child_state] = child;
                children ~= child;
            }
        }

        static bool more_novel(GameState!T a, GameState!T b){
            return a.parents.length < b.parents.length;
        }

        sort!more_novel(children);

        assert(state_children.length == children.length);
    }

    void make_children()
    {
        GameState!T[State!T] empty;
        make_children(empty);
    }

    bool update_value(){
        debug(update_value) {
            writeln("Updating value: ", &this);
            writeln(low_value, ", ", high_value);
            //writeln(this);
        }
        if (low_value == high_value){
            return false;
        }
        auto old_low_value = low_value;
        auto old_high_value = high_value;
        if (!is_leaf){
            float sign;
            if (state.black_to_play){
                sign = +1;
            }
            else{
                sign = -1;
            }
            low_value = -sign * float.infinity;
            high_value = -sign * float.infinity;
            foreach (child; children){
                if (child.low_value * sign > low_value * sign){
                    low_value = child.low_value;
                }
                if (child.high_value * sign > high_value * sign){
                    high_value = child.high_value;
                }
            }
        }
        else{
            low_value = high_value = state.liberty_score;
        }
        
        debug(update_value) {
            foreach (child; children){
                writeln(" Child: ", &child);
                writeln(" ", child.low_value, ", ", child.high_value);
            }
            writeln(low_value, ", ", high_value);
        }
        return (old_low_value != low_value || old_high_value != high_value);
    }

    void populate_game_tree(
        ref GameState!T[State!T] state_pool,
        ref GameState!T[] leaf_queue
        )
    {
        if (!populated){
            populated = true;
            assert(state_pool[state] == this);
            if (is_leaf){
                leaf_queue ~= this;
                return;
            }

            make_children(state_pool);

            foreach (child; children){
                child.populate_game_tree(state_pool, leaf_queue);
            }
        }
    }

    void update_parents()
    {
        foreach (parent; parents){
            bool changed = parent.update_value;
            if (changed){
                parent.update_parents;
            }
        }
    }

    void calculate_minimax_value()
    {
        GameState!T[State!T] state_pool = [state: this];
        GameState!T[] leaf_queue;
        populate_game_tree(state_pool, leaf_queue);

        foreach (leaf; leaf_queue){
            leaf.update_parents;
        }
    }

    /*
    void calculate_minimax_value(
            float depth,
            bool use_transpositions,
            ref GameState!T[State!T] transpositions,
            bool[State!T] history,
            ref GameState!T[State!T] state_pool
        )
    {
        debug(minimax) {
            if (state_pool.length > pool_size){
                writeln("Minimaxing:");
                writeln(state_pool.length);
                pool_size = state_pool.length;
            }
            writeln(this);
        }

        if (depth <= 0){
            return;
        }

        if (complete){
            return;
        }

        if (use_transpositions){
            if (!canonical_state_available){
                canonical_state = state;
                canonical_state.canonize;
                canonical_state_available = true;
            }
            if (canonical_state in transpositions){
                auto transposition = transpositions[canonical_state];
                assert(transposition.complete);
                assert(transposition.canonical_state == canonical_state);
                low_value = transposition.low_value;
                high_value = transposition.high_value;
                complete = true;
                bool[State!T] empty;
                dependencies = empty;
                children = [];
                release_all_hooks;
                return;
            }
        }

        if (!(state in state_pool)){
            state_pool[state] = this;
        }
        assert(state_pool[state] is this);

        if (is_leaf){
            return;
        }

        make_children(state_pool);

        history = history.dup;
        history[state] = true;

        foreach (child; children){
            if (!child.is_leaf){
                if (child.state in history){
                    child.hook(this);
                }
                else{
                    child.calculate_minimax_value(
                        depth - 1,
                        use_transpositions,
                        transpositions,
                        history,
                        state_pool
                    );
                    foreach (dependency; child.dependencies.byKey){
                        if (dependency in history){
                            child.hook(this, dependency);
                        }
                    }
                }
            }
        }

        update_value;

        if (!dependencies.length){
            complete = true;
        }

        release_hooks(complete);

        if (!dependencies.length){
            //release_hooks;
            complete = true;
            if (use_transpositions){
                assert(canonical_state_available);
                debug(transpositions) {
                    writeln("Saving transposition:");
                    writeln(this);
                }
                transpositions[canonical_state] = this;
            }
            debug(complete){
                writeln("Complete!");
                writeln(this);
            }
        }

        debug(minimax) {
            writeln("Done minimaxing.");
            writeln(low_value, ", ", high_value);
        }
    }

    void calculate_minimax_value(bool use_transpositions=false)
    {
        GameState!T[State!T] transpositions;
        bool[State!T] history;
        GameState!T[State!T] state_pool;
        calculate_minimax_value(
            float.infinity,
            use_transpositions,
            transpositions,
            history,
            state_pool
        );
    }
    */

    /*
    void calculate_self_minimax_value(bool[State!T] history=null, GameState!T[State!T] state_pool=null)
    {
        if (is_leaf){
            return;
        }

        make_children(state_pool);

        if (history is null){
            history = [state : true];
        }
        else{
            history = history.dup;
            history[state] = true;
        }

        foreach (child; children){
            if (!child.is_leaf){
                if (!(child.state in history)){
                    child.calculate_minimax_value(history, state_pool);
                    foreach (dependency; child.dependencies.byKey){
                        if (dependency != state){
                            child.hook(this, dependency);
                        }
                    }
                }
            }
        }

        update_value;
    }
    */

    override string toString()
    {
        return format(
            "%s\nlow_value=%s high_value=%s number of children=%s",
            state,
            low_value,
            high_value,
            children.length
        );
    }

    GameState!T[] principal_path(string type)(int max_depth=100)
    {
        if (max_depth <= 0){
            return [];
        }
        GameState!T[] result = [this];
        auto _children = children.dup;
        if (state.black_to_play && type == "high"){
            _children.reverse;
        }
        else if (!state.black_to_play && type == "low"){
            _children.reverse;
        }
        foreach(child; _children){
            if (mixin("child." ~ type ~ "_value == " ~ type ~ "_value")){
                result ~= child.principal_path!type(max_depth - 1);
                break;
            }
        }
        return result;
    }
}

unittest
{
    auto gs = new GameState!Board8(rectangle!Board8(1, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == 0);
    assert(gs.high_value == 0);

    gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == -2);
    assert(gs.high_value == 2);

    gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.state.opponent = Board8(0, 0);
    gs.state.ko = Board8(1, 0);
    gs.calculate_minimax_value;
    assert(gs.low_value == -2);
    assert(gs.high_value == 2);

    gs = new GameState!Board8(rectangle!Board8(3, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == 3);
    assert(gs.high_value == 3);
}

unittest
{
    auto gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.calculate_minimax_value;
    foreach (p; gs.principal_path!"high"){
        assert(!p.dependencies.length);
        auto c = p.copy;
        c.calculate_minimax_value;
        assert(c.low_value == p.low_value);
        assert(c.high_value == p.high_value);
    }
    foreach (p; gs.principal_path!"low"){
        assert(!p.dependencies.length);
        auto c = p.copy;
        c.calculate_minimax_value;
        assert(c.low_value == p.low_value);
        assert(c.high_value == p.high_value);
    }
}

unittest
{
    auto gs = new GameState!Board8(rectangle!Board8(3, 1));
    gs.calculate_minimax_value;
    void check_children(GameState!Board8 gs, ref bool[State!Board8] checked){
        foreach (child; gs.children){
            if (!(child.state in checked)){
                checked[child.state] = true;
                check_children(child, checked);
            }
        }
        auto c = gs.copy;
        c.calculate_minimax_value;
        writeln(gs);
        writeln(c.low_value, ", ", c.high_value);
        assert(c.low_value == gs.low_value);
        assert(c.high_value == gs.high_value);
    }
    bool[State!Board8] checked;
    check_children(gs, checked);
}

version(all_tests){
    unittest
    {
        auto gs = new GameState!Board8(rectangle!Board8(4, 1));
        gs.calculate_minimax_value;
        assert(gs.low_value == 4);
        assert(gs.high_value == 4);

        gs = new GameState!Board8(rectangle!Board8(2, 2));
        gs.calculate_minimax_value;
        assert(gs.low_value == -4);
        assert(gs.high_value == 4);
    }
}

/*
void main()
{
    auto gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.state.black_to_play = false;
    gs.state.opponent |= Board8(1, 0);
    gs.calculate_minimax_value;
    foreach (p; gs.principal_path!"low"){
        writeln(p);
        //writeln(p.dependencies);
        writeln;
    }
}
*/
/*
void main()
{
    offending_state = State!Board8(rectangle!Board8(2, 1));
    offending_state.opponent = Board8(0, 0);
    offending_state.ko = Board8(1, 0);
    offending_state.black_to_play = false;


    auto gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.calculate_minimax_value;
    foreach (p; gs.principal_path!"high"(5)){
        writeln(p);
        foreach (dependency, dummy; p.dependencies){
            writeln("-----------dependency-----------");
            writeln(dependency);
            assert(dependency == offending_state);
        }
        if (p.dependencies.length) writeln("*********");
        writeln;
    }
    //writeln(gs);
}
*/

/*
void main()
{
    auto gs = new GameState!Board8(rectangle!Board8(4, 1));
    //auto gs = new GameState!Board8(rectangle!Board8(2, 2));
    gs.calculate_minimax_value;
    writeln(gs);
}
*/
