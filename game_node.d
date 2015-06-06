module game_node;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;

import utils;
import board8;
import state;


/**
* GameNode is a wrapper around State structs that maintains a list of descendants and predecessors (of which there can be multiple).
* It doesn't have a single value. Instead it determines a range of possible values allowed by rulesets with varying super-ko rules.
*/

struct Transposition
{
    float low_value;
    float high_value;
}

class GameNode(T, S)
{
    S state;
    float low_value = -float.infinity;
    float high_value = float.infinity;
    bool is_leaf = false;
    bool is_final = false;
    GameNode!(T, S)[] children;
    GameNode!(T, S)[] parents;

    this(T playing_area)
    {
        this(S(playing_area));
    }

    this(S state, Transposition[S] *transpositions=null)
    {
        this.state = state;
        if (state.is_leaf){
            is_leaf = true;
            is_final = true;
            low_value = high_value = state.liberty_score;
        }
        else if (transpositions !is null){
            auto key = state;
            key.value_shift = 0;
            if (key in *transpositions){
                auto transposition = (*transpositions)[key];
                low_value = transposition.low_value + state.value_shift;
                high_value = transposition.high_value + state.value_shift;
                is_final = true;
            }
        }
    }

    invariant
    {
        assert(state.passes <= 2);
        assert(low_value <= high_value);
    }

    GameNode!(T, S) copy(){
        return new GameNode!(T, S)(state);
    }

    void make_children(ref GameNode!(T, S)[S] node_pool, Transposition[S] *transpositions=null)
    {
        if (is_leaf || children.length){
            return;
        }

        foreach (child_state; state.children){
            assert(child_state.black_to_play);
            if (child_state in node_pool){
                auto child = node_pool[child_state];
                children ~= child;
                child.parents ~= this;
            }
            else{
                auto child = new GameNode!(T, S)(child_state, transpositions);
                children ~= child;
                child.parents ~= this;
                node_pool[child.state] = child;
            }
        }

        //children.randomShuffle;

        static bool more_novel(GameNode!(T, S) a, GameNode!(T, S) b){
            return a.parents.length < b.parents.length;
        }

        sort!more_novel(children);
    }

    void make_children(Transposition[S] *transpositions)
    {
        GameNode!(T, S)[S] empty;
        make_children(empty, transpositions);
    }

    bool update_value()
    {
        if (is_leaf || is_final){
            // The value should've been set in the constructor.
            return false;
        }

        float new_low_value = -float.infinity;
        float new_high_value = -float.infinity;

        foreach (child; children){
            if (-child.high_value > new_low_value){
                new_low_value = -child.high_value;
            }
            if (-child.low_value > new_high_value){
                new_high_value = -child.low_value;
            }
        }

        assert(new_low_value >= low_value);
        assert(new_high_value <= high_value);
        assert(new_low_value <= new_high_value);

        bool changed = (new_low_value != low_value) || (new_high_value != high_value);
        low_value = new_low_value;
        high_value = new_high_value;
        if (low_value == high_value){
            is_final = true;
        }
        return changed;
    }

    void populate_game_tree(ref GameNode!(T, S)[S] node_pool, ref SetQueue!(GameNode!(T, S)) leaf_queue, Transposition[S] *transpositions=null)
    {
        SetQueue!(GameNode!(T, S)) queue;

        queue.insert(this);

        while (!queue.empty){
            auto game_node = queue.removeFront;
            debug (populate){
                writeln("Populating with:");
                writeln(game_node);
            }
            if (game_node.is_leaf || game_node.is_final){
                leaf_queue.insert(game_node);
            }
            else if (!game_node.children.length){
                game_node.make_children(node_pool, transpositions);

                foreach (child; game_node.children){
                    queue.insert(child);
                }
            }
        }
    }

    void calculate_minimax_values(Transposition[S] *transpositions=null)
    {
        GameNode!(T, S)[S] node_pool;
        SetQueue!(GameNode!(T, S)) leaf_queue;

        node_pool[state] = this;

        populate_game_tree(node_pool, leaf_queue, transpositions);

        SetQueue!(GameNode!(T, S)) queue;
        foreach (leaf; leaf_queue.queue){
            foreach (parent; leaf.parents){
                queue.insert(parent);
            }
        }

        while (!queue.empty){
            auto node = queue.removeFront;
            if (node.update_value){
                foreach (parent; node.parents){
                    queue.insertBack(parent);
                }
            }
        }

        foreach (node; node_pool.byValue){
            node.is_final = true;
            if (transpositions !is null){
                auto key = node.state;
                key.value_shift = 0;
                (*transpositions)[key] = Transposition(node.low_value - node.state.value_shift, node.high_value - node.state.value_shift);
            }
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

    /*
    GameNode!(T, S)[] high_children()
    {
        GameNode!(T, S)[] result;
        if (!is_leaf && !children.length){
            make_children;
        }
        foreach (child; children){
            if (-child.low_value == high_value){
                result ~= child;
            }
        }
        return result;
    }

    GameNode!(T, S)[] low_children()
    {
        GameNode!(T, S)[] result;
        if (!is_leaf && !children.length){
            make_children;
        }
        foreach (child; children){
            if (-child.high_value == low_value){
                result ~= child;
            }
        }
        return result;
    }
    */

    GameNode!(T, S)[] principal_path(string type)(int max_depth=100)
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
        GameNode!(T, S)[] result = [this];
        bool found_one = false;
        foreach(child; children){
            if (mixin("-child." ~ other_type ~ "_value == " ~ type ~ "_value && -child." ~ type ~ "_value == " ~ type ~ "_value")){
                result ~= child.principal_path!other_type(max_depth - 1);
                found_one = true;
                break;
            }
        }

        if (!found_one){
            foreach(child; children){
                if (mixin("-child." ~ other_type ~ "_value == " ~ type ~ "_value")){
                    result ~= child.principal_path!other_type(max_depth - 1);
                    break;
                }
            }
        }

        foreach (i, previous_state; result){
            foreach (j, other_state; result[i+1..$]){
                if (other_state == previous_state){
                    return result[0..j];
                }
            }
        }

        return result;
    }
}

alias GameNode8 = GameNode!(Board8, CanonicalState8);
//alias DefenseGameNode8 = GameNode!(Board8, DefenseState8);

unittest
{
    auto gs = new GameNode8(rectangle8(1, 1));
    gs.calculate_minimax_values;
    assert(gs.low_value == 0);
    assert(gs.high_value == 0);

    gs = new GameNode8(rectangle8(2, 1));
    gs.calculate_minimax_values;
    assert(gs.low_value == -2);
    assert(gs.high_value == 2);

    auto state = State8(rectangle8(2, 1));
    state.opponent = Board8(0, 0);
    state.ko = Board8(1, 0);
    gs = new GameNode8(CanonicalState8(state));
    gs.calculate_minimax_values;
    assert(gs.low_value == -2);
    assert(gs.high_value == 2);

    gs = new GameNode8(rectangle8(3, 1));
    gs.calculate_minimax_values;
    assert(gs.low_value == 3);
    assert(gs.high_value == 3);
}

unittest
{
    auto gs = new GameNode8(rectangle8(2, 1));
    gs.calculate_minimax_values;
    foreach (p; gs.principal_path!"high"){
        auto c = p.copy;
        c.calculate_minimax_values;
        assert(c.low_value == p.low_value);
        assert(c.high_value == p.high_value);
    }
    foreach (p; gs.principal_path!"low"){
        auto c = p.copy;
        c.calculate_minimax_values;
        assert(c.low_value == p.low_value);
        assert(c.high_value == p.high_value);
    }
}

unittest
{
    auto gs = new GameNode8(rectangle8(3, 1));
    gs.calculate_minimax_values;
    void check_children(GameNode8 gs, ref bool[CanonicalState8] checked){
        foreach (child; gs.children){
            if (child.state !in checked){
                checked[child.state] = true;
                check_children(child, checked);
            }
        }
        auto c = gs.copy;
        c.calculate_minimax_values;
        assert(c.low_value == gs.low_value);
        assert(c.high_value == gs.high_value);
    }
    bool[CanonicalState8] checked;
    check_children(gs, checked);
}

unittest
{
    auto gs = new GameNode8(rectangle8(4, 1));
    gs.calculate_minimax_values;
    assert(gs.low_value == 4);
    assert(gs.high_value == 4);

    gs = new GameNode8(rectangle8(2, 2));
    gs.calculate_minimax_values;
    assert(gs.low_value == -4);
    assert(gs.high_value == 4);
}

unittest
{
    auto gs = new GameNode8(rectangle8(3, 2));
    gs.calculate_minimax_values;
    assert(gs.low_value == -6);
    assert(gs.high_value == 6);
}

/*
unittest
{
    auto s = DefenseState8(rectangle8(4, 3));
    s.player = rectangle8(4, 3) & ~rectangle8(3, 2) | Board8(2, 1);
    s.player_target = s.player;
    s.ko_threats = -float.infinity;

    auto gs = new DefenseGameNode8(s);

    gs.calculate_minimax_values;

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

    auto gs = new DefenseGameNode8(s);
    gs.calculate_minimax_values;
    assert(gs.low_value == float.infinity);
    assert(gs.high_value == float.infinity);

    s.opponent_outside_liberties = 1;
    gs = new DefenseGameNode8(s);
    gs.calculate_minimax_values;
    assert(gs.low_value == float.infinity);
    assert(gs.high_value == float.infinity);

    s.opponent_outside_liberties = 2;
    gs = new DefenseGameNode8(s);
    gs.calculate_minimax_values;
    assert(gs.low_value == -14);
    assert(gs.high_value == -14);
}
*/
