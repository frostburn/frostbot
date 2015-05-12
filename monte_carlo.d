module monte_carlo;

import std.stdio;
import std.string;
import std.random;
import std.conv;
import std.math;
import std.array;

import utils;
import pattern3;
import board8;
import state;
import defense_state;
import defense_search_state;
import defense;

T weighted_choice(T)(T[] items, int[] weights)
{
    int sum = 0;
    foreach (weight; weights){
        assert(weight >= 0);
        sum += weight;
    }
    if (sum == 0){
        return items[uniform(0, items.length)];
    }
    int break_point = uniform(0, sum);
    int index = 0;
    foreach (weight; weights){
        break_point -= weight;
        if (break_point < 0){
            break;
        }
        index++;
    }
    return items[index];
}

S child_by_pattern3(S)(S state, int[Pattern3] pattern_weights)
{
    S[] children;
    Pattern3[] patterns;
    int[] weights;
    state.children_with_pattern3(children, patterns);
    if (!children.length){
        state.pass;
        return state;
    }
    foreach (pattern; patterns){
        pattern.canonize;
        if (pattern in pattern_weights){
            weights ~= pattern_weights[pattern];
        }
        else {
            weights ~= 8;
        }
    }
    return weighted_choice(children, weights);
}

struct DefaultNode(T, S)
{
    S state;
    T player_secure;
    T opponent_secure;
    float value;

    private
    {
        T[] moves;
    }

    this(S state, T player_secure, T opponent_secure, T[] moves)
    in
    {
        assert(state.black_to_play);
    }
    body
    {
        this.state = state;
        this.player_secure = player_secure;
        this.opponent_secure = opponent_secure;
        this.moves = moves;
    }

    /*
    void unbiased_playout(int trials=100)
    {
        bool success;

        foreach (i; 0..trials){
            T move = moves[uniform(0, moves.length)];
            success = state.make_move(move);
        }

        value = state.liberty_score;
    }
    */

    void playout(int trials=120)
    {
        bool success;
        T ko1;
        T ko2;

        if (!moves.length){
            value = controlled_liberty_score(state, T(), T(), T(), T(), player_secure, opponent_secure);
            return;
        }

        foreach (i; 0..trials){
            size_t r = uniform!size_t;
            T move;
            auto temp = r & 3;
            r >>= 2;
            if (ko1 && (temp) == 0){
                move = ko1;
            }
            else{
                move = moves[r % moves.length];
                r /= moves.length;
            }
            if (move){
                T blob = move.blob(state.playing_area);
                if (blob.popcount == 9){
                    if ((blob & state.player).popcount >= 8){
                        continue;
                    }
                }
                else if (!(blob & ~state.player)){
                    continue;
                }
            }
            else{
                temp = r & 7;
                temp >>= 3;
                if (temp > 0){
                    continue;
                }
            }
            success = state.make_move(move);
            if (state.is_leaf){
                break;
            }
            // Accentuate first move advantage.
            if (!state.black_to_play && i < 4){
                state.swap_turns;
            }
            ko1 = ko2;
            ko2 = state.ko;
        }

        value = controlled_liberty_score(state, T(), T(), T(), T(), player_secure, opponent_secure);
    }

    string toString()
    {
        return format("%s\n%s", state, value);
    }
}

alias DefaultNode8 = DefaultNode!(Board8, State8);


struct Statistics
{
    ulong[] bins;
    ulong confidence = 0;

    float[] decay_bins;

    private
    {
        int shift;
    }

    int lower_bound() @property
    {
        return -shift;
    }

    int upper_bound() @property
    {
        return (cast(int)bins.length) - shift - 1;
    }

    this(int lower_bound, int upper_bound)
    in
    {
        assert(lower_bound <= upper_bound);
    }
    body
    {
        bins.length = upper_bound - lower_bound + 1;
        decay_bins.length = bins.length;
        decay_bins[] = 0;
        shift = -lower_bound;
        if (lower_bound == upper_bound){
            bins[0] = ulong.max;
            confidence = ulong.max;
            decay_bins[0] = float.infinity;
        }
    }

    void set_bounds(int lower_bound, int upper_bound)
    in
    {
        assert(lower_bound <= upper_bound);
    }
    body
    {
        if (lower_bound > this.lower_bound || upper_bound < this.upper_bound){
            if (lower_bound < this.lower_bound){
                lower_bound = this.lower_bound;
            }
            if (upper_bound > this.upper_bound){
                upper_bound = this.upper_bound;
            }
            size_t lower_index = lower_bound + shift;
            size_t upper_index = upper_bound + shift + 1;
            bins = bins[lower_index..upper_index];
            decay_bins = decay_bins[lower_index..upper_index];
            shift = -lower_bound;
            if (lower_bound == upper_bound){
                bins[0] = ulong.max;
                decay_bins[0] = float.infinity;
            }

            confidence = 0;
            foreach (bin; bins){
                confidence += bin;
            }
        }
    }

    float add_value(float value)
    in
    {
        //assert(value == -float.infinity || value == float.infinity || (value + shift >= 0 && value + shift < bins.length));
        assert(confidence < ulong.max);
    }
    body
    {
        /*
        if (value == -float.infinity){
            negative_infinity_bin++;
        }
        else if (value == float.infinity){
            positive_infinity_bin++;
        }
        else{
            */
        float index = value + shift;
        if (index < 0){
            index = 0;
        }
        else if (index >= bins.length){
            index = bins.length - 1;
        }
        bins[to!size_t(index)]++;
        confidence++;
        decay_bins[to!size_t(index)] += 1.0;
        // TODO: Optimize: Instead of decaying each bin add the new value exponentially multiplied.
        foreach (ref decay_bin; decay_bins){
            decay_bin *= 0.9995;
        }

        return index - shift;
    }

    float average()
    {
        float e = 0;
        foreach (index, bin; bins){
            e += (to!float(index) - shift) * bin;
        }
        if (confidence == 0){
            return -shift;
        }
        else{
            return e / confidence;
        }
    }

    float decay_average()
    {
        float e = 0;
        float total = 0;
        foreach (index, decay_bin; decay_bins){
            e += (to!float(index) - shift) * decay_bin;
            total += decay_bin;
        }
        if (total == 0 || total == float.infinity){
            return -shift;
        }
        else{
            return e / total;
        }
    }

    /*
    float p_positive_infinity()
    {
        float total = positive_infinity_bin + negative_infinity_bin;
        foreach (bin; bins){
            total += bin;
        }
        return positive_infinity_bin / total;
    }

    float p_negative_infinity()
    {
        float total = positive_infinity_bin + negative_infinity_bin;
        foreach (bin; bins){
            total += bin;
        }
        return positive_infinity_bin / total;
    }
    */

    string toString()
    {
        ulong max = 1;
        foreach (bin; bins){
            if (bin > max){
                max = bin;
            }
        }
        enum height = 20;


        string r;
        foreach (y; 0..height){
            foreach (x; 0..bins.length){
                size_t bin_height;
                if (max < ulong.max / 8 / height){
                    bin_height = (8 * height * bins[x]) / max;
                }
                else{
                    bin_height = (8 * height) * (bins[x] / max);
                }
                auto target_height = 8 * (height - y);
                if (bin_height >= target_height){
                    r ~= "█";
                }
                else if (bin_height >= target_height - 1){
                    r ~= "▇";
                }
                else if (bin_height >= target_height - 2){
                    r ~= "▆";
                }
                else if (bin_height >= target_height - 3){
                    r ~= "▅";
                }
                else if (bin_height >= target_height - 4){
                    r ~= "▄";
                }
                else if (bin_height >= target_height - 5){
                    r ~= "▃";
                }
                else if (bin_height >= target_height - 6){
                    r ~= "▂";
                }
                else if (bin_height >= target_height - 7){
                    r ~= "▁";
                }
                else{
                    r ~= " ";
                }
            }
            r ~= "\n";
        }
        return format("%sAverage=%s", r, average);
    }
}


class TreeNode(T, S, C)
{
    C state;
    T player_secure;
    T opponent_secure;
    Statistics statistics;
    ulong visits = 1;

    TreeNode!(T, S, C)[] children;
    TreeNode!(T, S, C)[C] parents;
    TreeNode!(T, S, C)[C] *node_pool;

    alias DefenseTranspositionTable = Transposition[DefenseState!T];
    DefenseTranspositionTable *defense_transposition_table=null;

    private
    {
        T[] moves;
    }

    int lower_bound() @property
    {
        return statistics.lower_bound;
    }

    int upper_bound() @property
    {
        return statistics.upper_bound;
    }

    ulong confidence() @property
    {
        return statistics.confidence;
    }

    bool is_final() @property
    {
        return lower_bound == upper_bound;
    }

    this (T playing_area, TreeNode!(T, S, C)[C] *node_pool=null, DefenseTranspositionTable *defense_transposition_table=null)
    {
        this(S(playing_area), node_pool, defense_transposition_table);
    }

    this (S state, TreeNode!(T, S, C)[C] *node_pool=null, DefenseTranspositionTable *defense_transposition_table=null)
    {
        this(C(state), node_pool, defense_transposition_table);
    }

    this (C state, TreeNode!(T, S, C)[C] *node_pool=null, DefenseTranspositionTable *defense_transposition_table=null)
    {
        state.analyze_unconditional(player_secure, opponent_secure);
        //auto result = analyze_state!(T, C)(state, player_secure, opponent_secure, defense_transposition_table);
        auto result = analyze_state_light!(T, C)(state, player_secure, opponent_secure);
        player_secure = result.player_secure;
        opponent_secure = result.opponent_secure;
        this.state = state;
        this.defense_transposition_table = defense_transposition_table;
        if (state.is_leaf){
            this.statistics = Statistics(to!int(result.score), to!int(result.score));
        }
        else{
            calculate_available_moves(result);
            this.statistics = Statistics(to!int(result.lower_bound), to!int(result.upper_bound));
            this.node_pool = node_pool;
        }
    }

    Statistics default_playout_statistics(size_t count)
    {
        auto result = analyze_state!(T, C)(state, player_secure, opponent_secure, defense_transposition_table);
        auto r = Statistics(to!int(result.lower_bound), to!int(result.upper_bound));
        auto default_node = DefaultNode!(T, S)(state.state, player_secure, opponent_secure, moves);
        foreach (i; 0..count){
            auto temp_node = default_node;
            temp_node.playout;
            r.add_value(temp_node.value);
        }
        return r;
    }

    float playout(){
        HistoryNode!C history = null;
        return playout(history);
    }

    float playout(ref HistoryNode!C history)
    {
        if (is_final){
            return this.value;
        }
        else{
            assert(visits < ulong.max);
            float value;
            if (visits < 20 || (history !is null && state in history)){
                auto default_node = DefaultNode!(T, S)(state.state, player_secure, opponent_secure, moves);
                default_node.playout;
                value = default_node.value;
            }
            else{
                auto my_history = new HistoryNode!C(state, history);
                auto child = choose_child;
                if (child is null){
                    return this.value;
                }
                value = -child.playout(my_history);
            }
            if (!is_final){
                value = statistics.add_value(value);
                visits++;
                return value;
            }
            else{
                return this.value;
            }
        }
    }

    bool update_bounds()
    {
        if (is_final){
            // There should be nothing left to do here.
            return false;
        }

        float old_lower_bound = lower_bound;
        float old_upper_bound = upper_bound;

        if (children.length){
            float new_lower_bound = -float.infinity;
            float new_upper_bound = -float.infinity;

            foreach (child; children){
                if (-child.upper_bound > new_lower_bound){
                    new_lower_bound = -child.upper_bound;
                }
                if (-child.lower_bound > new_upper_bound){
                    new_upper_bound = -child.lower_bound;
                }
            }

            debug (update_bounds){
                foreach (child; children){
                    writeln("c: ", child.lower_bound, ", ", child.upper_bound);
                }
                writeln(to!int(new_lower_bound));
                writeln(to!int(new_upper_bound));
            }
            statistics.set_bounds(to!int(new_lower_bound), to!int(new_upper_bound));
        }

        return old_lower_bound != lower_bound || old_upper_bound != upper_bound;
    }

    float value()
    {
        return statistics.average * 0.6 + statistics.decay_average * 0.4;
    }

    void update_parents()
    {
        debug(update_parents) {
            writeln("Updating parents for:");
            writeln(this);
        }
        TreeNode!(T, S, C)[] queue;
        foreach (parent; parents.byValue){
            queue ~= parent;
        }

        while (queue.length){
            auto tree_node = queue.front;
            queue.popFront;
            debug(update_parents) {
                writeln("Updating parents for:");
                writeln(tree_node);
            }
            bool changed = tree_node.update_bounds;
            if (changed){
                foreach (parent; tree_node.parents){
                    queue ~= parent;
                }
            }
        }
    }

    TreeNode!(T, S, C) choose_child()
    {
        if (!children.length){
            make_children;
            bool changed = update_bounds;
            if (changed){
                update_parents;
            }
            if (is_final){
                return null;
            }
        }

        TreeNode!(T, S, C)[] valid_children;
        foreach (child; children){
            if (!child.is_final && -child.lower_bound >= lower_bound){
                valid_children ~= child;
            }
        }

        assert(valid_children.length);


        TreeNode!(T, S, C)[] young_children;
        foreach (child; valid_children){
            if (child.visits < 20){
                young_children ~= child;
            }
        }
        if (young_children.length){
            return young_children[uniform(0, young_children.length)];
        }

        TreeNode!(T, S, C) best_child;
        float best_value = -float.infinity;
        enum exploration_constant = 7.0;

        foreach (child; valid_children){
            float child_value = -child.value + exploration_constant * sqrt(log(visits) / (child.confidence + 1));
            //writeln(child_value);
            if (child_value >= best_value){
                best_value = child_value;
                best_child = child;
            }
        }
        //writeln(best_value);
        //writeln(best_child);

        return best_child;
    }

    void calculate_available_moves(DefenseAnalysisResult!T result)
    {
        int y_max = state.playing_area.vertical_extent;
        int x_max = state.playing_area.horizontal_extent;

        for (int y = 0; y < y_max; y++){
            for (int x = 0; x < x_max; x++){
                T move = T(x, y);
                if (move & state.playing_area & ~player_secure & ~opponent_secure & ~result.player_useless){
                    moves ~= move;
                }
            }
        }
        moves ~= T();
    }

    void make_children()
    {
        foreach (child_state; state.children(moves)){
            if (node_pool !is null && child_state in *node_pool){
                auto child = (*node_pool)[child_state];
                child.parents[state] = this;
                children ~= child;
            }
            else{
                auto child = new TreeNode!(T, S, C)(child_state, node_pool);
                child.parents[state] = this;
                children ~= child;
                if (node_pool !is null){
                    (*node_pool)[child_state] = child;
                }
            }
        }
    }

    TreeNode!(T, S, C) best_child()
    {
        if (!children.length){
            make_children;
        }

        TreeNode!(T, S, C) best_child;
        float best_value = -float.infinity;

        // TODO: Factor in confidence.
        foreach (child; children){
            if (-child.value >= best_value){
                best_value = -child.value;
                best_child = child;
            }
        }
        return best_child;
    }

    override string toString()
    {
        return format(
            "%s\nlower bound=%s, upper_bound=%s, value=%s, visits=%s, final=%s, number of children=%s",
            state._toString(T(), T(), player_secure, opponent_secure),
            lower_bound, upper_bound, value, visits, is_final, children.length
        );
    }
}

alias TreeNode8 = TreeNode!(Board8, State8, CanonicalState8);
