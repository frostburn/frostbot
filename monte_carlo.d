module monte_carlo;

import std.stdio;
import std.string;
import std.random;
import std.conv;
import std.math;

import board8;
import state;

struct DefaultNode(T, S)
{
    S state;
    T player_unconditional;
    T opponent_unconditional;
    float value;

    private
    {
        T[] moves;
    }

    this(S state, T player_unconditional, T opponent_unconditional, T[] moves)
    {
        this.state = state;
        this.player_unconditional = player_unconditional;
        this.opponent_unconditional = opponent_unconditional;
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
            }
            T blob = move.blob(state.playing_area);
            if (blob.popcount == 9){
                if ((blob & state.player).popcount >= 8){
                    continue;
                }
            }
            else if (!(blob & ~state.player)){
                continue;
            }
            success = state.make_move(move);
            ko1 = ko2;
            ko2 = state.ko;
        }

        value = controlled_liberty_score(state, player_unconditional, opponent_unconditional);
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
    ulong negative_infinity_bin;
    ulong positive_infinity_bin;

    private
    {
        float shift;
    }

    this(int playing_area_size)
    {
        bins.length = 2 * playing_area_size + 1;
        shift = playing_area_size;
    }

    void add_value(float value)
    in
    {
        assert(value == -float.infinity || value == float.infinity || (value + shift >= 0 && value + shift < bins.length));
    }
    body
    {
        if (value == -float.infinity){
            negative_infinity_bin++;
        }
        else if (value == float.infinity){
            positive_infinity_bin++;
        }
        else{
            bins[to!size_t(value + shift)]++;
        }
    }

    float average()
    {
        float e = 0;
        float total = 0;
        foreach (index, bin; bins){
            e += (index - shift) * bin;
            total += bin;
        }
        if (total == 0){
            return 0;
        }
        else{
            return e / total;
        }
    }

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
                auto bin_height = (8 * height * bins[x]) / max;
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
    T player_unconditional;
    T opponent_unconditional;
    Statistics statistics;
    ulong visits = 1;
    bool is_leaf;

    TreeNode!(T, S, C)[] children;
    TreeNode!(T, S, C)[C] *node_pool;

    private
    {
        T[] moves;
    }

    this (T playing_area, TreeNode!(T, S, C)[C] *node_pool=null)
    {
        this(S(playing_area), node_pool);
    }

    this (S state, TreeNode!(T, S, C)[C] *node_pool=null)
    {
        this(C(state), node_pool);
    }

    this (C state, TreeNode!(T, S, C)[C] *node_pool=null)
    {
        this.state = state;
        if (state.is_leaf){
            is_leaf = true;
        }
        else{
            state.analyze_unconditional(player_unconditional, opponent_unconditional);
            calculate_available_moves;
            this.statistics = Statistics(state.playing_area.popcount);  // TODO: Needs shifts for CanonicalDefenseState.
            this.node_pool = node_pool;
        }
    }

    Statistics default_playout_statistics(size_t count)
    {
        auto r = Statistics(state.playing_area.popcount);
        auto default_node = DefaultNode!(T, S)(state.state, player_unconditional, opponent_unconditional, moves);
        foreach (i; 0..count){
            auto temp_node = default_node;
            temp_node.playout;
            r.add_value(temp_node.value);
        }
        return r;
    }

    float playout()
    {
        if (is_leaf){
            return this.value;
        }
        else{
            float value;
            if (visits < 12){
                auto default_node = DefaultNode!(T, S)(state.state, player_unconditional, opponent_unconditional, moves);
                default_node.playout;
                value = default_node.value;
            }
            else{
                auto child = choose_child;
                value = -child.playout;
            }
            statistics.add_value(value);
            visits++;
            return value;
        }
    }

    float value()
    {
        if (is_leaf){
            return controlled_liberty_score(state, player_unconditional, opponent_unconditional);
        }
        else{
            return statistics.average;
        }
    }

    TreeNode!(T, S, C) choose_child()
    {
        if (!children.length){
            make_children;
        }

        TreeNode!(T, S, C)[] young_children;
        foreach (child; children){
            if (child.visits < 42){
                young_children ~= child;
            }
        }
        if (young_children.length){
            return young_children[uniform(0, young_children.length)];
        }

        TreeNode!(T, S, C) best_child;
        float best_value = -float.infinity;
        enum exploration_constant = 7.0;

        foreach (child; children){
            float child_value = -child.value + exploration_constant * sqrt(log(visits) / child.visits);
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

    void calculate_available_moves()
    {
        int y_max = state.playing_area.vertical_extent;
        int x_max = state.playing_area.horizontal_extent;

        for (int y = 0; y < y_max; y++){
            for (int x = 0; x < x_max; x++){
                T move = T(x, y);
                if (move & state.playing_area & ~player_unconditional & ~opponent_unconditional){
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
                children ~= (*node_pool)[child_state];
            }
            else{
                auto child = new TreeNode!(T, S, C)(child_state, node_pool);
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
            "%s\nvalue=%s, visits=%s, leaf=%s, number of children=%s",
            state._toString(T(), T(), player_unconditional, opponent_unconditional),
            value, visits, is_leaf, children.length
        );
    }
}

alias TreeNode8 = TreeNode!(Board8, State8, CanonicalState8);


float controlled_liberty_score(T, S)(S state, T player_unconditional, T opponent_unconditional)
{
    float score = state.target_score;

    if (score == 0){
        auto player_controlled_terrirory = (state.player | player_unconditional) & ~opponent_unconditional;
        auto opponent_controlled_terrirory = (state.opponent | opponent_unconditional) & ~(opponent_unconditional);

        score += player_controlled_terrirory.popcount;
        score -= opponent_controlled_terrirory.popcount;

        score += player_controlled_terrirory.liberties(state.playing_area & ~opponent_controlled_terrirory).popcount;
        score -= opponent_controlled_terrirory.liberties(state.playing_area & ~player_controlled_terrirory).popcount;

        return score + state.value_shift;
    }
    else{
        return score;
    }
}