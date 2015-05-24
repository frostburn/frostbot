module hl_node;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;

import utils;
import board8;
import state;
import game_node;
import local;


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

    T moves;
    Transposition[LocalState!T] *local_transpositions = null;

    // TODO: check_queue for recently modified nodes.

    this(S state, HLNode!(T, S)[S] *node_pool, Transposition[LocalState!T] *local_transpositions=null)
    {
        this.state = state;
        this.node_pool = node_pool;
        this.local_transpositions = local_transpositions;
        assert(state !in *node_pool);
        (*node_pool)[state] = this;
        if (state.is_leaf){
            is_leaf = true;
            low = high = state.liberty_score;
            is_low_final = is_high_final = true;
        }
        else {
            version (no_local){
                state.get_score_bounds(low, high);
            }
            else {
                analyze_state(state, moves, low, high, local_transpositions);
            }
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

        version (no_local){
            auto _moves = state.moves;
        }
        else {
            auto _moves = moves.pieces ~ T();
        }
        foreach (child_state; state.children(_moves)){
            assert(child_state.black_to_play);
            if (child_state in *node_pool){
                auto child = (*node_pool)[child_state];
                children ~= child;
                child.parents[state] = this;
            }
            else{
                auto child = new HLNode!(T, S)(child_state, node_pool, local_transpositions);
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

        float new_low = low;
        float new_high = -float.infinity;
        foreach (child; children){
            if (-child.high > new_low){
                new_low = -child.high;
            }
            if (-child.low > new_high){
                new_high = -child.low;
            }
        }

        if (new_high > high){
            new_high = high;
        }
        if (new_low > new_high){
            writeln(this);
            writeln(new_low, ", ", new_high);
        }
        assert(new_low <= new_high);

        bool changed = (new_low != low || new_high != high);
        low = new_low;
        high = new_high;

        if (low == high){
            is_low_final = is_high_final = true;
        }

        return changed;
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

    HLNode!(T, S)[] low_children()
    {
        HLNode!(T, S)[] result;
        if (!is_leaf && !children.length){
            make_children;
        }
        foreach (child; children){
            if (-child.high == low && child.is_high_final){
                result ~= child;
            }
        }
        return result;
    }

    string low_solution()
    {
        auto low_children = this.low_children;
        T mark;
        auto moves = state.moves;
        auto child_states = state.children(moves);
        foreach (i, child_state; child_states){
            foreach (child; low_children){
                if (child.state == child_state){
                    mark |= moves[i];
                }
            }
        }
        return format("%s\n%s <= score <= %s", state._toString(T(), T(), state.player_unconditional, state.opponent_unconditional, mark), low, high);
    }

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


unittest
{
    HLNode8[CanonicalState8] empty;
    auto node_pool = &empty;

    auto a = rectangle8(5, 2) ^ Board8(0, 0);
    auto p = Board8(1, 1);
    auto o = Board8(4, 1);
    auto pu = Board8(3, 0) | Board8(4, 0);
    auto ou = Board8(1, 0) | Board8(2, 0) | Board8(0, 1);

    auto s = State8(a);
    s.player = p | pu;
    s.opponent = o | ou;
    s.player_unconditional = pu;
    s.opponent_unconditional = ou;

    auto n = new HLNode8(CanonicalState8(s), node_pool);

    while (n.expand) {
    }

    assert(n.low == 1);
    assert(n.high == 1);
}

unittest
{
    Transposition[LocalState8] loc_trans;
    auto transpositions = &loc_trans;
    HLNode8[CanonicalState8] empty;
    auto node_pool = &empty;

    auto b = Board8(0, 0);
    b = b.cross(full8).cross(full8).cross(full8);
    auto o = b.liberties(full8) ^ Board8(4, 0) ^ Board8(1, 2);
    b = b.cross(full8);
    auto p = rectangle8(3, 2) ^ Board8(2, 0) ^ Board8(3, 0) ^ Board8(0, 1) ^ Board8(0, 2);

    auto s = State8(b);
    s.player = p;
    s.opponent = o;
    s.opponent_unconditional = o;

    auto n = new HLNode8(CanonicalState8(s), node_pool, transpositions);

    while (n.expand) {
    }
    assert(n.low == -15);
    assert(n.high == -15);
}