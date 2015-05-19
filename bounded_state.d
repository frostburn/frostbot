module bounded_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import board8;
import state;


ulong next_tag = 1;


static bool is_better(T, S)(BoundedState!(T, S) a, BoundedState!(T, S) b){
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

    if (a.high_upper_bound < b.high_upper_bound){
        return true;
    }
    if (a.high_upper_bound > b.high_upper_bound){
        return false;
    }
    if (a.low_lower_bound < b.low_lower_bound){
        return true;
    }
    if (a.low_lower_bound > b.low_lower_bound){
        return false;
    }

    auto a_euler = a.state.opponent.euler - a.state.player.euler;
    auto b_euler = b.state.opponent.euler - b.state.player.euler;

    if (a_euler < b_euler){
        return true;
    }
    if (b_euler < a_euler){
        return false;
    }

    auto a_popcount = a.state.opponent.popcount - a.state.player.popcount - a.state.value_shift;
    auto b_popcount = b.state.opponent.popcount - b.state.player.popcount - b.state.value_shift ;

    if (a_popcount > b_popcount){
        return true;
    }
    if (b_popcount > a_popcount){
        return false;
    }

    return false;
}


class BoundedState(T, S)
{
    S state;
    float low_lower_bound = -float.infinity;
    float high_lower_bound = -float.infinity;
    float low_upper_bound = float.infinity;
    float high_upper_bound = float.infinity;
    bool is_leaf = false;
    BoundedState!(T, S)[] children;
    BoundedState!(T, S)[S] parents;
    BoundedState!(T, S)[S] *state_pool = null;
    ulong tag = 0;

    version (assert){
        float previous_low_upper_bound;
        float previous_high_lower_bound;
    }

    this(S state, BoundedState!(T, S)[S] *state_pool)
    {
        this.state = state;
        this.state_pool = state_pool;
        assert(state !in *state_pool);
        (*state_pool)[state] = this;
        if (state.is_leaf){
            is_leaf = true;
            low_lower_bound = high_lower_bound = low_upper_bound = high_upper_bound = state.liberty_score;
        }
        else {
            state.get_score_bounds(low_lower_bound, high_upper_bound);
            high_lower_bound = low_lower_bound;
            low_upper_bound = high_upper_bound;
        }
    }

    invariant
    {
        assert(state.passes <= 2);
    }

    bool is_final()
    {
        return low_lower_bound == low_upper_bound && high_lower_bound == high_upper_bound;
    }

    void make_children()
    {
        assert(!is_leaf);
        children = [];

        foreach (child_state; state.children){
            assert(child_state.black_to_play);
            if (child_state in *state_pool){
                auto child = (*state_pool)[child_state];
                children ~= child;
                child.parents[state] = this;
            }
            else{
                auto child = new BoundedState!(T, S)(child_state, state_pool);
                children ~= child;
                child.parents[state] = this;
            }
        }
        //children.randomShuffle;
        sort!(is_better!(T, S))(children);
    }

    bool update_value()
    {
        if (is_leaf){
            // The value should've been set in the constructor.
            return false;
        }

        float old_low_lower_bound = low_lower_bound;
        float old_high_lower_bound = high_lower_bound;
        float old_low_upper_bound = low_upper_bound;
        float old_high_upper_bound = high_upper_bound;

        low_lower_bound = -float.infinity;
        low_upper_bound = -float.infinity;
        high_lower_bound = -float.infinity;
        high_upper_bound = -float.infinity;
        foreach (child; children){
            if (-child.high_upper_bound > low_lower_bound){
                low_lower_bound = -child.high_upper_bound;
            }
            if (-child.low_upper_bound > high_lower_bound){
                high_lower_bound = -child.low_upper_bound;
            }
            if (-child.high_lower_bound > low_upper_bound){
                low_upper_bound = -child.high_lower_bound;
            }
            if (-child.low_lower_bound > high_upper_bound){
                high_upper_bound = -child.low_lower_bound;
            }
        }
        /*
        if (low_upper_bound < low_lower_bound){
            low_upper_bound = low_lower_bound;
        }
        if (high_lower_bound > high_upper_bound){
            high_lower_bound = high_upper_bound;
        }
        */
        //assert(low_upper_bound <= old_low_upper_bound);
        assert(high_upper_bound <= old_high_upper_bound);
        assert(low_lower_bound >= old_low_lower_bound);
        //assert(high_lower_bound >= old_high_lower_bound);
        assert(low_lower_bound <= low_upper_bound);
        assert(high_lower_bound <= high_upper_bound);
        assert(low_lower_bound <= high_upper_bound);

        return (
            old_low_lower_bound != low_lower_bound ||
            old_high_lower_bound != high_lower_bound ||
            old_low_upper_bound != low_upper_bound ||
            old_high_upper_bound != high_upper_bound
        );
    }

    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        BoundedState!(T, S)[] queue;
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

    void calculate_current_values()
    {
        // TODO: Collect a parent set to update instead.
        BoundedState!(T, S)[] leaf_queue;

        foreach (bounded_state; (*state_pool).byValue){
            version (assert){
                bounded_state.previous_low_upper_bound = bounded_state.low_upper_bound;
                bounded_state.previous_high_lower_bound = bounded_state.high_lower_bound;
            }
            if (bounded_state.is_leaf || !bounded_state.children.length){
                // DOESN'T INCLUDE ALL NODES WHOSE PARENTS NEED CHECKING!
                leaf_queue ~= bounded_state;
            }
            else {
                // LEADS TO INCORRECT BEHAVIOUR!
                bounded_state.low_upper_bound = bounded_state.low_lower_bound;
                bounded_state.high_lower_bound = bounded_state.high_upper_bound;
            }
        }

        foreach (leaf; leaf_queue){
            leaf.update_parents;
        }

        version (assert){
            foreach (bounded_state; (*state_pool).byValue){
                //writeln(bounded_state.previous_low_upper_bound, ", ", bounded_state.previous_high_lower_bound);
                //writeln(bounded_state);
                assert(bounded_state.previous_low_upper_bound >= bounded_state.low_upper_bound);
                assert(bounded_state.previous_high_lower_bound <= bounded_state.high_lower_bound);
            }
        }
    }

    void full_expand()
    {
        bool again = true;
        while (again){
            again = false;
            foreach (bounded_state; (*state_pool).byValue){
                if (!bounded_state.is_leaf && !bounded_state.children.length){
                    bounded_state.make_children;
                    again = true;
                }
            }
        }
        calculate_current_values;
    }

    bool expand()
    {
        calculate_current_values;
        if (is_final){
            return false;
        }
        auto result = expand(next_tag++);
        assert(result);
        return true;
    }

    bool expand(ulong tag)
    {
        if (this.tag == tag){
            return false;
        }
        this.tag = tag;
        if (!children.length){
            make_children;
            return true;
        }
        bool done = false;
        foreach (child; children){
            if (-child.high_upper_bound == low_lower_bound && -child.high_lower_bound != low_lower_bound){
                if (child.expand(tag)){
                    done = true;
                    break;
                    //return true;
                }
            }
        }
        foreach (child; children){
            if (-child.low_upper_bound == high_lower_bound && -child.low_lower_bound != high_lower_bound){
                if (child.expand(tag)){
                    done = true;
                    break;
                    //return true;
                }
            }
        }
        foreach (child; children){
            if (-child.high_lower_bound == low_upper_bound && -child.high_upper_bound != low_upper_bound){
                if (child.expand(tag)){
                    done = true;
                    break;
                    //return true;
                }
            }
        }
        foreach (child; children){
            if (-child.low_lower_bound == high_upper_bound && -child.low_upper_bound != high_upper_bound){
                if (child.expand(tag)){
                    done = true;
                    break;
                    //return true;
                }
            }
        }
        if (done){
            return true;
        }
         return false;
         /*
        // Loops suck. I get it.
        foreach (child; children){
            if (child.high_lower_bound != child.high_upper_bound){
                if (child.expand(tag)){
                    return true;
                }
            }
        }
        foreach (child; children){
            if (child.low_lower_bound != child.low_upper_bound){
                if (child.expand(tag)){
                    return true;
                }
            }
        }
        return false;
        */
        /*
        // OK. This is just desperate.
        foreach (child; children){
            if (!child.is_leaf && child.tag != tag){
                if (child.expand(tag) != ExpansionResult.loop){
                    return ExpansionResult.success;
                }
            }
        }
        */
        /*
        if (low_lower_bound == low_upper_bound && high_lower_bound == high_upper_bound){
            return ExpansionResult.done;
        }
        else {
            return ExpansionResult.loop;
        }
        */
    }

    BoundedState!(T, S)[] principal_path(string type)(int max_depth=100, bool same=false)
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
        BoundedState!(T, S)[] result = [this];
        bool found_one = false;
        foreach(child; children){
            if (
                mixin("-child." ~ other_type ~ "_lower_bound == " ~ type ~ "_lower_bound && -child." ~ type ~ "_lower_bound == " ~ type ~ "_lower_bound") &&
                mixin("-child." ~ other_type ~ "_upper_bound == " ~ type ~ "_upper_bound && -child." ~ type ~ "_upper_bound == " ~ type ~ "_upper_bound")
            ){
                if (same){
                    result ~= child.principal_path!type(max_depth - 1);
                }
                else {
                    result ~= child.principal_path!other_type(max_depth - 1);
                }
                found_one = true;
                break;
            }
        }

        if (!found_one){
            foreach(child; children){
                if (mixin("-child." ~ other_type ~ "_lower_bound == " ~ type ~ "_lower_bound && -child." ~ other_type ~ "_upper_bound == " ~ type ~ "_upper_bound")){
                    if (same){
                        result ~= child.principal_path!type(max_depth - 1);
                    }
                    else {
                        result ~= child.principal_path!other_type(max_depth - 1);
                    }
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

    override string toString()
    {
        return format(
            "%s\n%s <= low <= %s\n%s <= high <= %s\nnumber of children=%s",
            state,
            low_lower_bound, low_upper_bound,
            high_lower_bound, high_upper_bound,
            children.length
        );
    }

    /*
    BoundedState!(T, S)[] principal_path(string type)(int max_depth=100)
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
        BoundedState!(T, S)[] result = [this];
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
    */
}

alias BoundedState8 = BoundedState!(Board8, CanonicalState8);
