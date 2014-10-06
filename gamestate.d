module gamestate;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;

import board8;
import state;


// TODO: Move to utils
bool member_in_list(T)(ref T member, ref T[] list){
    foreach (list_member; list){
        if (member is list_member){
            return true;
        }
    }
    return false;
}


debug(minimax) static size_t pool_size;


class GameState(T)
{
    State!T state;
    float low_value = -float.infinity;
    float high_value = float.infinity;
    bool is_leaf;
    GameState!T[] children;
    GameState!T[] parents;

    private
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
            if (moves is null){
                calculate_available_moves();
            }
            else{
                this.moves = moves;
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

    void create_canonical_state(){
        if (!canonical_state_available){
            canonical_state = state;
            canonical_state.canonize;
            canonical_state_available = true;
        }
    }

    void make_children(ref GameState!T[State!T] state_pool, bool use_transpositions)
    {
        GameState!T child;
        auto state_children = state.children(moves);
        children = [];
        foreach (child_state; state_children){
            if (use_transpositions){
                child_state.canonize;
            }
            if (child_state in state_pool){
                child = state_pool[child_state];
                if (!use_transpositions || !(member_in_list!(GameState!T)(child, children))){
                    if (!member_in_list!(GameState!T)(this, child.parents)){
                        child.parents ~= this;
                    }
                   children ~= child;
                }
            }
            else{
                if (!use_transpositions){
                    child = new GameState!T(child_state, moves);
                }
                else{
                    child = new GameState!T(child_state);
                    child.canonical_state = child_state;
                    child.canonical_state_available = true;
                    //child.create_canonical_state;
                }
                child.parents ~= this;
                state_pool[child_state] = child;
                children ~= child;
            }
        }

        static bool more_novel(GameState!T a, GameState!T b){
            return a.parents.length < b.parents.length;
        }

        sort!more_novel(children);

        if (!use_transpositions){
            assert(state_children.length == children.length);
        }
    }

    void make_children()
    {
        GameState!T[State!T] empty;
        make_children(empty, false);
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
            float child_low_value, child_high_value;
            if (state.black_to_play){
                sign = +1;
            }
            else{
                sign = -1;
            }
            low_value = -sign * float.infinity;
            high_value = -sign * float.infinity;
            foreach (child; children){
                if (state.black_to_play != child.state.black_to_play){
                    child_low_value = child.low_value;
                    child_high_value = child.high_value;
                }
                else{
                    child_low_value = -child.high_value;
                    child_high_value = -child.low_value;
                }
                if (child_low_value * sign > low_value * sign){
                    low_value = child_low_value;
                }
                if (child_high_value * sign > high_value * sign){
                    high_value = child_high_value;
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

    // TODO: Create a non-recursive version
    void populate_game_tree(
        ref GameState!T[State!T] state_pool,
        ref GameState!T[] leaf_queue,
        bool use_transpositions
        )
    {
        debug(populate) {
            writeln("Populating tree for:");
            writeln(this);
        }
        if (!populated){
            populated = true;
            if (use_transpositions){
                assert(canonical_state_available);
                assert(canonical_state in state_pool);
                assert(state_pool[canonical_state] == this);
            }
            else{
                assert(state_pool[state] == this);
            }
            if (is_leaf){
                leaf_queue ~= this;
                return;
            }

            make_children(state_pool, use_transpositions);

            foreach (child; children){
                child.populate_game_tree(state_pool, leaf_queue, use_transpositions);
            }
        }
    }

    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        GameState!T[] queue;
        foreach (parent; parents){
            queue ~= parent;
        }
        while (queue.length){
            auto state = queue.front;
            queue.popFront;
            bool changed = state.update_value;
            if (changed){
                foreach (parent; state.parents){
                    queue ~= parent;
                }
            }
        }
    }

    /*
    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        foreach (parent; parents){
            bool changed = parent.update_value;
            if (changed){
                parent.update_parents;
            }
        }
    }
    */

    void calculate_minimax_value(bool use_transpositions=false)
    {
        GameState!T[State!T] state_pool;
        GameState!T[] leaf_queue;

        if (use_transpositions){
            create_canonical_state;
            state_pool[canonical_state] = this;
        }
        else{
            state_pool[state] = this;
        }

        populate_game_tree(state_pool, leaf_queue, use_transpositions);

        foreach (leaf; leaf_queue){
            leaf.update_parents;
        }
    }

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

    // TODO: Add support for transposed paths.
    GameState!T[] principal_path(string type)(int max_depth=100)
    {
        static assert(type == "high" || type == "low");
        if (max_depth <= 0){
            return [];
        }
        GameState!T[] result = [this];
        foreach(child; children){
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
        auto c = p.copy;
        c.calculate_minimax_value;
        assert(c.low_value == p.low_value);
        assert(c.high_value == p.high_value);
    }
    foreach (p; gs.principal_path!"low"){
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
        assert(c.low_value == gs.low_value);
        assert(c.high_value == gs.high_value);
    }
    bool[State!Board8] checked;
    check_children(gs, checked);
}

//version(all_tests){
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

    unittest
    {
        auto gs = new GameState!Board8(rectangle!Board8(2, 3));
        gs.calculate_minimax_value(true);
        assert(gs.low_value == -6);
        assert(gs.high_value == 6);
    }
//}
