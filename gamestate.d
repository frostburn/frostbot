module gamestate;

import std.stdio;
import std.string;
import std.algorithm;


debug(minimax) static size_t pool_size;

class GameState(T)
{
    State!T state;
    float low_value = -float.infinity;
    float high_value = float.infinity;
    bool is_leaf;
    GameState!T[] children;
    GameState!T[] parents;
    bool complete;

    private
    {
        T[] moves;
        bool[GameState!T][State!T] hooks;
        bool[State!T] dependencies;
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

        if (is_leaf){
            assert(!hooks.length);
            assert(!dependencies.length);
        }

        if (complete){
            assert(!dependencies.length);
        }
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

    void make_children(GameState!T[State!T] state_pool=null)
    {
        auto state_children = state.children(moves);
        children = [];
        foreach (child_state; state_children){
            if (!(state_pool is null) && child_state in state_pool){
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
                if (!(state_pool is null)){
                    state_pool[child_state] = child;
                }
                children ~= child;
            }
        }

        static bool more_novel(GameState!T a, GameState!T b){
            return a.parents.length < b.parents.length;
        }

        sort!more_novel(children);

        assert(state_children.length == children.length);
    }

    void hook(GameState!T other, State!T key)
    {
        if (!(key in hooks)){
            bool[GameState!T] empty;
            hooks[key] = empty;
        }
        hooks[key][other] = true;
        other.dependencies[key] = true;
    }

    void hook(GameState!T other)
    {
        hook(other, state);
    }

    void release_hooks(State!T key){
        debug(release_hooks) {
            writeln("Releasing hooks with key:");
            writeln(key);
        }
        auto hooks_dup = hooks.dup;
        if (key in hooks_dup){
            foreach(hook; hooks_dup[key].dup.byKey){
                hook.update_value;
                hook.dependencies.remove(key);
                if (key in hooks){
                    hooks[key].remove(hook);
                }
                hook.release_hooks(key);
                if (!hook.dependencies.length){
                    hook.release_all_hooks;
                }
            }
            hooks.remove(key);
        }
    }

    void release_hooks(){
        release_hooks(state);
    }

    void release_all_hooks(){
        foreach(key; hooks.dup.byKey){
            release_hooks(key);
        }
    }

    void update_value(){
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
            foreach(child; children){
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
        if (low_value == high_value){
            complete = true;
            bool[State!T] empty;
            dependencies = empty;
            debug(complete){
                writeln("Complete!");
                writeln(this);
            }
        }
        
    }

    void calculate_minimax_value(bool[State!T] history=null, GameState!T[State!T] state_pool=null){
        debug(minimax) {
            if (state_pool.length > pool_size){
                writeln("Minimaxing:");
                writeln(state_pool.length);
                pool_size = state_pool.length;
            }
        }

        if (complete){
            return;
        }

        if (state_pool is null){
            GameState!T[State!T] empty;
            state_pool = empty;
        }
        if (!(state in state_pool)){
            state_pool[state] = this;
        }
        assert(state_pool[state] is this);

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
                if (child.state in history){
                    child.hook(this);
                }
                else{
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

        release_hooks;

        if (!dependencies.length){
            //release_hooks;
            complete = true;
            debug(complete){
                writeln("Complete!");
                writeln(this);
            }
        }
    }

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
