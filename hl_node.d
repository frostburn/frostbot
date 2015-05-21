module hl_node;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import board8;
import state;


ulong next_tag = 1;


static bool is_better(T, S)(HLNode!(T, S) a, HLNode!(T, S) b){
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

    if (a.high < b.high){
        return true;
    }
    if (a.high > b.high){
        return false;
    }
    if (a.low < b.low){
        return true;
    }
    if (a.low > b.low){
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


class HLNode(T, S)
{
    S state;
    float low = -float.infinity;
    float high = float.infinity;
    bool is_low_final = false;
    bool is_high_final = false;
    bool is_leaf = false;
    HLNode!(T, S)[] children;
    HLNode!(T, S)[S] parents;
    HLNode!(T, S)[S] *node_pool = null;
    ulong low_tag = 0;
    ulong high_tag = 0;
    // TODO: check_queue for recently modified nodes.

    this(S state, HLNode!(T, S)[S] *node_pool)
    {
        this.state = state;
        this.node_pool = node_pool;
        assert(state !in *node_pool);
        (*node_pool)[state] = this;
        if (state.is_leaf){
            is_leaf = true;
            low = high = state.liberty_score;
            is_low_final = is_high_final = true;
        }
        else {
            state.get_score_bounds(low, high);
            is_low_final = is_high_final = (low == high);
        }
    }

    invariant
    {
        assert(state.passes <= 2);
    }

    bool is_final()
    {
        return is_low_final && is_high_final;
    }

    // TODO: Add this to check_queue.
    void make_children()
    {
        assert(!is_leaf);
        children = [];

        foreach (child_state; state.children){
            assert(child_state.black_to_play);
            if (child_state in *node_pool){
                auto child = (*node_pool)[child_state];
                children ~= child;
                child.parents[state] = this;
            }
            else{
                auto child = new HLNode!(T, S)(child_state, node_pool);
                children ~= child;
                child.parents[state] = this;
            }
        }
        children.randomShuffle;
        sort!(is_better!(T, S))(children);
    }

    // TODO: Make cascading.
    bool update_value()
    {
        if (is_final || !children.length){
            return false;
        }

        float old_low = low;
        float old_high = high;

        high = -float.infinity;
        foreach (child; children){
            if (-child.high > low){
                low = -child.high;
            }
            if (-child.low > high){
                high = -child.low;
            }
        }
        assert(high <= old_high);
        assert(low >= old_low);
        assert(low <= high);

        if (low == high){
            is_low_final = is_high_final = true;
        }

        return (old_low != low || old_high != high);
    }

    void calculate_current_values()
    {
        // TODO: Use cascading update instead.
        HLNode!(T, S)[] queue;
        HLNode!(T, S)[] leaf_queue;
        foreach (node; *node_pool){
            if (!node.is_final){
                queue ~= node;
            }
            if (node.is_leaf){
                leaf_queue ~= node;
            }
        }

        while (queue.length){
            auto node = queue.front;
            queue.popFront;
            bool changed = node.update_value;
            if (changed){
                foreach (parent; node.parents){
                    queue ~= parent;
                }
            }
        }

        /*
        foreach (leaf; leaf_queue){
            leaf.update_low_finality(next_tag++);
            leaf.update_high_finality(next_tag++);
        }
        */
        foreach (node; *node_pool){
            node.update_low_finality(next_tag++);
            node.update_high_finality(next_tag++);
        }
    }

    bool update_high_finality(ulong tag)
    {
        if (this.high_tag == tag){
            return true;
        }
        this.high_tag = tag;

        if (is_high_final){
            //foreach (parent; parents){
            //    parent.update_low_finality(tag);
            //}
            return true;
        }

        // Check if my high could change by a non selected low getting higher.
        foreach (child; children){
            if (-child.high < high && !child.update_low_finality(tag)){
                return false;
            }
        }
        // Check if my high could change by the selected low getting higher.
        foreach (child; children){
            if (-child.low == high && child.update_low_finality(tag)){
                is_high_final = true;
                foreach (parent; parents){
                    parent.update_low_finality(next_tag++);
                }
                return true;
            }
        }
        return false;
    }

    bool update_low_finality(ulong tag)
    {
        if (this.low_tag == tag){
            return true;
        }
        this.low_tag = tag;

        if (is_low_final){
            //foreach (parent; parents){
            //    parent.update_high_finality(tag);
            //}
            return true;
        }

        // Check if my low could change by a non selected high getting lower.
        foreach (child; children){
            if (-child.low > low && !child.update_high_finality(tag)){
                return false;
            }
        }
        // Check if my low could change by the selected high getting lower.
        foreach (child; children){
            if (-child.high == low && child.update_high_finality(tag)){
                is_low_final = true;
                foreach (parent; parents){
                    parent.update_high_finality(next_tag++);
                }
                return true;
            }
        }

        return false;
    }

    void full_expand()
    {
        bool again = true;
        while (again){
            again = false;
            foreach (bounded_state; (*node_pool).byValue){
                if (!bounded_state.is_leaf && !bounded_state.children.length){
                    bounded_state.make_children;
                    again = true;
                }
            }
        }
        foreach (bounded_state; (*node_pool).byValue){
            if (!bounded_state.is_leaf){
                bounded_state.low = -float.infinity;
                bounded_state.high = float.infinity;
                bounded_state.is_low_final = false;
                bounded_state.is_high_final = false;
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
        bool result;
        if (!is_low_final){
            result = expand_low(next_tag++);
            assert(result);
        }
        if (!is_high_final){
            result = expand_high(next_tag++);
            assert(result);
        }
        return true;
    }

    bool expand_low(ulong tag)
    {
        assert(!is_low_final);
        if (this.low_tag == tag){
            return false;
        }
        this.low_tag = tag;
        if (!children.length){
            make_children;
            return true;
        }
        int expansions = 0;
        foreach (child; children){
            if (-child.high == low && !child.is_high_final){
                if (child.expand_high(tag)){
                    expansions++;
                    break;
                    //return true;
                }
            }
        }
        foreach (child; children){
            if (-child.low > low && !child.is_high_final){
                if (child.expand_high(tag)){
                    expansions++;
                    break;
                    //return true;
                }
            }
        }
        if (expansions){
            return true;
        }
        return false;
    }

    bool expand_high(ulong tag)
    {
        assert(!is_high_final);
        if (this.high_tag == tag){
            return false;
        }
        this.high_tag = tag;
        if (!children.length){
            make_children;
            return true;
        }
        int expansions = 0;
        foreach (child; children){
            if (-child.low == high && !child.is_low_final){
                if (child.expand_low(tag)){
                    expansions++;
                    break;
                    //return true;
                }
            }
        }
        foreach (child; children){
            if (-child.high < high && !child.is_low_final){
                if (child.expand_low(tag)){
                    expansions++;
                    break;
                    //return true;
                }
            }
        }
        if (expansions){
            return true;
        }
        return false;
    }

    /*
    HLNode!(T, S)[] principal_path(string type)(int max_depth=100, bool same=false)
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
        HLNode!(T, S)[] result = [this];
        bool found_one = false;
        foreach(child; children){
            if (mixin("-child." ~ other_type ~ " == " ~ type ~ " && -child." ~ type ~ " == " ~ type)){
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
    */

    override string toString()
    {
        string low_mark, high_mark;
        if (is_low_final){
            low_mark = "=";
        }
        else {
            low_mark = ">=";
        }
        if (is_high_final){
            high_mark = "=";
        }
        else {
            high_mark = "<=";
        }
        return format(
            "%s\nlow %s %s\nhigh %s %s\nnumber of children=%s",
            state,
            low_mark, low,
            high_mark, high,
            children.length
        );
    }
}

alias HLNode8 = HLNode!(Board8, CanonicalState8);
