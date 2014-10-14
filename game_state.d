module game_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;

import utils;
import board8;
import state;
import defense_state;


/**
* GameState is a wrapper around State structs that maintains a list of descendants and predecessors (of which there can be multiple).
* It doesn't have a single value. Instead it determines a range of possible values allowed by rulesets with varying super-ko rules.
*/


class GameState(T, S)
{
    S state;
    float low_value = -float.infinity;
    float high_value = float.infinity;
    int value_shift = 0;
    bool is_leaf = false;
    GameState!(T, S)[] children;
    GameState!(T, S)[S] parents;

    private
    {
        T[] moves;
        bool is_populated = false;
    }

    this(T playing_area)
    {
        this(S(playing_area));
    }

    this(S state, int value_shift=0, T[] moves=null)
    {
        this.state = state;
        this.value_shift = value_shift;
        if (state.is_leaf){
            is_leaf = true;
            low_value = high_value = state.liberty_score + value_shift;
        }
        else{
            if (moves is null){
                calculate_available_moves;
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

    GameState!(T, S) copy(){
        return new GameState!(T, S)(state);
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

    void make_children(ref GameState!(T, S)[S] state_pool)
    {
        children = [];

        // Prune out transpositions.
        S[] child_states;
        int[] child_value_shifts;
        bool[S] seen;
        foreach (child_state; state.children(moves)){
            int child_value_shift = child_state.reduce;
            child_state.canonize;
            if (child_state !in seen){
                seen[child_state] = true;
                child_states ~= child_state;
                child_value_shifts ~= child_value_shift;
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
                int child_value_shift = child_value_shifts[index];

                T[] child_moves = null;
                if (child_state.playing_area == state.playing_area){
                    child_moves = moves;
                }
                auto child = new GameState!(T, S)(child_state, child_value_shift - value_shift, child_moves);
                children ~= child;
                child.parents[state] = this;
                state_pool[child.state] = child;
            }
        }

        //children.randomShuffle;

        static bool more_novel(GameState!(T, S) a, GameState!(T, S) b){
            return a.parents.length < b.parents.length;
        }

        sort!more_novel(children);
    }

    void make_children()
    {
        GameState!(T, S)[S] empty;
        make_children(empty);
    }

    bool update_value()
    {
        if (is_leaf){
            // The value should've been set in the constructor.
            return false;
        }

        float old_low_value = low_value;
        float old_high_value = high_value;

        low_value = -float.infinity;
        high_value = -float.infinity;

        foreach (child; children){
            if (-child.high_value > low_value){
                low_value = -child.high_value;
            }
            if (-child.low_value > high_value){
                high_value = -child.low_value;
            }
        }

        debug(ss_update_value){
            if (low_value > -float.infinity && high_value < float.infinity){
                writeln("Updating value: max=", state.black_to_play);
                writeln("Old value: ", old_low_value, ", ", old_high_value);
                foreach (child; children){
                    writeln(" Child: ", child.low_value, ", ", child.high_value, " max=", child.state.black_to_play);
                }
                writeln("New value: ", low_value, ", ", high_value);
            }
        }

        return (old_low_value != low_value) || (old_high_value != high_value);
    }

    void populate_game_tree(ref GameState!(T, S)[S] state_pool, ref GameState!(T, S)[] leaf_queue)
    {
        GameState!(T, S)[] queue;

        queue ~= this;

        while (queue.length){
            auto game_state = queue.front;
            queue.popFront;
            debug(populate) {
                writeln("Populating with:");
                writeln(game_state);
            }
            if (!game_state.is_populated){
                assert(game_state.state in state_pool);
                assert(state_pool[game_state.state] == game_state);

                game_state.is_populated = true;

                if (game_state.is_leaf){
                    leaf_queue ~= game_state;
                    continue;
                }

                game_state.make_children(state_pool);

                foreach (child; game_state.children){
                    queue ~= child;
                }
            }
        }
    }

    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        GameState!(T, S)[] queue;
        foreach (parent; parents){
            queue ~= parent;
        }

        while (queue.length){
            auto game_state = queue.front;
            queue.popFront;
            debug(update_parents) {
                writeln("Updating parents for:");
                writeln(game_state);
            }
            bool changed = game_state.update_value;
            if (changed){
                foreach (parent; game_state.parents){
                    queue ~= parent;
                }
            }
        }
    }

    void calculate_minimax_value()
    {
        GameState!(T, S)[S] state_pool;
        GameState!(T, S)[] leaf_queue;

        state_pool[state] = this;

        populate_game_tree(state_pool, leaf_queue);

        foreach (leaf; leaf_queue){
            leaf.update_parents;
        }
    }

    override string toString()
    {
        return format(
            "%s\nlow_value=%s high_value=%s value_shift=%s number of children=%s",
            state,
            low_value,
            high_value,
            value_shift,
            children.length
        );
    }

    GameState!(T, S)[] principal_path(string type)(int max_depth=100)
    {
        static assert(type == "high" || type == "low");
        static if (type == "high"){
            enum other_type = "low";
        }
        else{
            enum other_type = "high";
        }
        if (max_depth <= 0){
            return [];
        }
        GameState!(T, S)[] result = [this];
        bool found_one = false;
        foreach(child; children){
            if (mixin("-child." ~ other_type ~ "_value == " ~ type ~ "_value && -child." ~ type ~ "_value == " ~ other_type ~ "_value")){
                result ~= child.principal_path!type(max_depth - 1);
                found_one = true;
                break;
            }
        }

        if (!found_one){
            foreach(child; children){
                if (mixin("-child." ~ other_type ~ "_value == " ~ type ~ "_value")){
                    result ~= child.principal_path!type(max_depth - 1);
                    break;
                }
            }
        }

        return result;
    }
}

alias GameState8 = GameState!(Board8, State8);
alias DefenseGameState8 = GameState!(Board8, DefenseState8);

unittest
{
    auto gs = new GameState8(rectangle8(1, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == 0);
    assert(gs.high_value == 0);

    gs = new GameState8(rectangle8(2, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == -2);
    assert(gs.high_value == 2);

    gs = new GameState8(rectangle8(2, 1));
    gs.state.opponent = Board8(0, 0);
    gs.state.ko = Board8(1, 0);
    gs.calculate_minimax_value;
    assert(gs.low_value == -2);
    assert(gs.high_value == 2);

    gs = new GameState8(rectangle8(3, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == 3);
    assert(gs.high_value == 3);
}

unittest
{
    auto gs = new GameState8(rectangle8(2, 1));
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
    auto gs = new GameState8(rectangle8(3, 1));
    gs.calculate_minimax_value;
    void check_children(GameState8 gs, ref bool[State8] checked){
        foreach (child; gs.children){
            if (child.state !in checked){
                checked[child.state] = true;
                check_children(child, checked);
            }
        }
        auto c = gs.copy;
        c.calculate_minimax_value;
        assert(c.low_value == gs.low_value);
        assert(c.high_value == gs.high_value);
    }
    bool[State8] checked;
    check_children(gs, checked);
}

unittest
{
    auto gs = new GameState8(rectangle8(4, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == 4);
    assert(gs.high_value == 4);

    gs = new GameState8(rectangle8(2, 2));
    gs.calculate_minimax_value;
    assert(gs.low_value == -4);
    assert(gs.high_value == 4);
}

unittest
{
    auto gs = new GameState8(rectangle8(3, 2));
    gs.calculate_minimax_value;
    assert(gs.low_value == -6);
    assert(gs.high_value == 6);
}

unittest
{
    auto s = DefenseState8(rectangle8(4, 3));
    s.player = rectangle8(4, 3) & ~rectangle8(3, 2) | Board8(2, 1);
    s.player_target = s.player;
    s.ko_threats = -float.infinity;

    auto gs = new DefenseGameState8(s);

    gs.calculate_minimax_value;

    assert(gs.low_value == 12);
    assert(gs.high_value == 12);
    foreach (child; gs.children){
        assert(child.value_shift < 0);
    }
}

unittest
{
    auto s = DefenseState8(rectangle8(5, 4) & ~(Board8(0, 0) | Board8(1, 0) | Board8(1, 2) | Board8(2, 2) | Board8(3, 2) | Board8(3, 1)));
    s.opponent = (rectangle8(5, 4) & ~rectangle8(3, 3).east) & s.playing_area;
    s.opponent_target = s.opponent;

    auto gs = new DefenseGameState8(s);
    gs.calculate_minimax_value;
    assert(gs.low_value == float.infinity);
    assert(gs.high_value == float.infinity);

    s.opponent_targets[0].outside_liberties = 1;
    gs = new DefenseGameState8(s);
    gs.calculate_minimax_value;
    assert(gs.low_value == float.infinity);
    assert(gs.high_value == float.infinity);

    s.opponent_targets[0].outside_liberties = 2;
    gs = new DefenseGameState8(s);
    gs.calculate_minimax_value;
    assert(gs.low_value == -14);
    assert(gs.high_value == -14);
}
