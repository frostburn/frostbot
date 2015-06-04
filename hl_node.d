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
    HLNode!(T, S)[] parents;
    //ulong low_tag = 0;
    //ulong high_tag = 0;

    T moves;

    this(S state, Transposition[LocalState!T] *local_transpositions=null)
    {
        this.state = state;
        if (state.is_leaf){
            is_leaf = true;
            // FIX: This really should come through analyze_state
            low = high = state.liberty_score;
            is_low_final = is_high_final = true;
        }
        else {
            version (no_local){
                state.get_score_bounds(low, high);
            }
            else {
                assert(false);
                analyze_state(state, moves, low, high, local_transpositions);
            }
            is_low_final = is_high_final = (low == high);
        }
    }

    invariant
    {
        assert(state.passes <= 2);
        assert(low <= high);
    }

    bool is_final()
    {
        return is_low_final && is_high_final;
    }

    void make_children(ref HLNode!(T, S)[S] node_pool, Transposition[LocalState!T] *local_transpositions=null)
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
            if (child_state in node_pool){
                auto child = node_pool[child_state];
                children ~= child;
                child.parents ~= this;
            }
            else{
                auto child = new HLNode!(T, S)(child_state, local_transpositions);
                node_pool[child_state] = child;
                children ~= child;
                child.parents ~= this;
            }
        }
        children.randomShuffle;
        sort!(is_better!(T, S))(children);
    }

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

    /*
    void calculate_current_values()
    {
        // TODO: Use cascading update from check queue instead.
        HLNode!(T, S)[] queue;
        foreach (node; *node_pool){
            if (!node.is_final){
                queue ~= node;
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


        if (is_final){
            return;
        }
        HLNode!(T, S)[S] escape_pool;
        _low_escapes(escape_pool);
        _high_escapes(escape_pool);


        foreach (node; escape_pool){
            assert(!node.is_final);
            foreach (parent; node.parents){
                queue ~= parent;
            }
        }

        while (queue.length){
            auto node = queue.front;
            queue.popFront;
            bool changed = node.update_low_finality;
            changed = changed || node.update_high_finality;
            if (changed){
                foreach (parent; node.parents){
                    queue ~= parent;
                }
            }
        }
    }
    */

    void _low_leaks(ref SetQueue!(HLNode!(T, S)) leak_queue)
    {
        if (children.length){
            is_low_final = true;
            foreach (child; children){
                if (-child.low > low && !child.is_high_final){
                    child._high_leaks(leak_queue);
                }
            }
        }
        else {
            leak_queue.insertBack(this);
        }
    }

    void _high_leaks(ref SetQueue!(HLNode!(T, S)) leak_queue)
    {
        if (children.length){
            is_high_final = true;
            foreach (child; children){
                if (-child.low == high && child.is_low_final){
                    return;
                }
                if (-child.high == high){
                    // This can happen if bounds checking is better on this node than on a child node.
                    return;
                }
            }
            foreach (child; children){
                if (-child.low >= high && !child.is_low_final){
                    child._low_leaks(leak_queue);
                }
            }
        }
        else {
            leak_queue.insertBack(this);
        }
    }

    bool update_low_finality(bool only_invalidate=false)
    {
        if (only_invalidate && !is_low_final){
            return false;
        }
        if (children.length){
            bool new_low_final = true;
            if (low != high){
                foreach (child; children){
                    if (-child.low > low && !child.is_high_final){
                        new_low_final = false;
                        break;
                    }
                }
            }
            bool changed = new_low_final != is_low_final;
            is_low_final = new_low_final;
            return changed;
        }
        else {
            return false;
        }
    }

    bool update_high_finality(bool only_invalidate=false)
    {
        if (only_invalidate && !is_high_final){
            return false;
        }
        if (children.length){
            bool new_high_final = false;
            if (low == high){
                new_high_final = true;
            }
            else {
                foreach (child; children){
                    if (-child.low == high && child.is_low_final){
                        new_high_final = true;
                        break;
                    }
                    if (-child.high == high){
                        // This can happen if bounds checking is better on this node than on a child node.
                        new_high_final = true;
                        break;
                    }
                }
            }
            bool changed = new_high_final != is_high_final;
            is_high_final = new_high_final;
            return changed;
        }
        else {
            return false;
        }
    }

    bool update_finality(bool only_invalidate=false)
    {
        bool low_result = update_low_finality(only_invalidate);
        bool high_result = update_high_finality(only_invalidate);
        return low_result || high_result;
    }

    /*
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
    */

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

    /*
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


class HLManager(T, S)
{
    HLNode!(T, S) root;
    HLNode!(T, S)[S] node_pool;
    Transposition[LocalState!T] *local_transpositions = null;

    private {
        SetQueue!(HLNode!(T, S)) queue;
    }

    this(S state, Transposition[LocalState!T] *local_transpositions=null)
    {
        root = new HLNode!(T, S)(state, local_transpositions);
        node_pool[state] = root;
        this.local_transpositions = local_transpositions;
        queue.insert(root);
    }

    bool expand(float limit=float.infinity)
    {
        assert(limit >= 1);
        while (!queue.empty){
            auto node = queue.removeFront;
            if (node.update_value){
                foreach (parent; node.parents){
                    queue.insertBack(parent);
                }
            }
        }
        SetQueue!(HLNode!(T, S)) leak_queue;
        root._low_leaks(leak_queue);
        root._high_leaks(leak_queue);
        if (leak_queue.empty){
            assert(root.is_final);
            return false;
        }
        foreach (node; leak_queue.queue){
            foreach (parent; node.parents){
                queue.insert(parent);
            }
        }
        while (!queue.empty){
            auto node = queue.removeFront;
            if (node.update_finality(true)){
                foreach (parent; node.parents){
                    queue.insertBack(parent);
                }
            }
        }
        float i = 0;
        foreach (node; leak_queue.queue){
            i += 1;
            if (i > limit){
                break;
            }
            node.make_children(node_pool, local_transpositions);
            queue.insert(node);
        }
        return true;
    }
}

alias HLManager8 = HLManager!(Board8, CanonicalState8);


unittest
{
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

    auto m = new HLManager8(CanonicalState8(s));

    while (m.expand){
    }
    assert(m.root.low == 1);
    assert(m.root.high == 1);
}

unittest
{
    Transposition[LocalState8] loc_trans;
    auto transpositions = &loc_trans;

    auto b = Board8(0, 0);
    b = b.cross(full8).cross(full8).cross(full8);
    auto o = b.liberties(full8) ^ Board8(4, 0) ^ Board8(1, 2);
    b = b.cross(full8);
    auto p = rectangle8(3, 2) ^ Board8(2, 0) ^ Board8(3, 0) ^ Board8(0, 1) ^ Board8(0, 2);

    auto s = State8(b);
    s.player = p;
    s.opponent = o;
    s.opponent_unconditional = o;

    auto m = new HLManager8(CanonicalState8(s), transpositions);

    while (m.expand) {
    }
    assert(m.root.low == -15);
    assert(m.root.high == -15);
}

unittest
{
    Transposition[LocalState8] loc_trans;
    auto transpositions = &loc_trans;

    auto s = State8(rectangle8(4, 1));
    auto m = new HLManager8(CanonicalState8(s), transpositions);
    while (m.expand) {
    }
    assert(m.root.low == 4);
    assert(m.root.high == 4);

    s = State8(rectangle8(5, 1));
    m = new HLManager8(CanonicalState8(s), transpositions);
    while (m.expand) {
    }
    assert(m.root.low == -5);
    assert(m.root.high == 5);

    s = State8(rectangle8(4, 2));
    m = new HLManager8(CanonicalState8(s), transpositions);
    while (m.expand) {
    }
    assert(m.root.low == 8);
    assert(m.root.high == 8);

    s = State8(rectangle8(4, 3));
    m = new HLManager8(CanonicalState8(s), transpositions);
    while (m.expand(600)) {
    }
    assert(m.root.low == 4);
    assert(m.root.high == 12);
}