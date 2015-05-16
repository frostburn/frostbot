module ab_state;

import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.random;
import std.math;

import utils;
import board8;
import state;

/**
* Alpha beta search
* Loops kill this because all the histories have to be searched separately.
*/


class ABState(T, S)
{
    S state;
    float low_value = float.nan;
    float high_value = float.nan;
    float low_lower_bound = -float.infinity;
    float high_lower_bound = -float.infinity;
    bool is_leaf = false;
    ABState!(T, S)[] children;
    ABState!(T, S)[S] *state_pool;

    this(S state, ABState!(T, S)[S] *state_pool)
    {
        this.state = state;
        this.state_pool = state_pool;
        if (state.is_leaf){
            is_leaf = true;
            low_value = high_value = low_lower_bound = high_lower_bound = state.liberty_score;
        }
    }

    invariant
    {
        assert(state.passes <= 2);
    }

    void make_children()
    {
        children = [];

        foreach (child_state; state.children){
            assert(child_state.black_to_play);
            if (child_state in *state_pool){
                auto child = (*state_pool)[child_state];
                children ~= child;
            }
            else{
                auto child = new ABState!(T, S)(child_state, state_pool);
                children ~= child;
                (*state_pool)[child.state] = child;
            }
        }
        children.randomShuffle;
    }

    void calculate_minimax_values()
    {
        low_value = low_lower_bound = minimax_low(null, null, -float.infinity, float.infinity);
        high_value = high_lower_bound = minimax_high(null, null, -float.infinity, float.infinity);
    }

    float minimax_low(HistoryNode!S *low_history, HistoryNode!S *high_history, float alpha, float beta)
    {
        debug (minimax){
            writeln("Low arguments:", alpha, ", ", beta);
        }
        if (!low_value.isNaN){
            return low_value;
        }
        if (low_history !is null && state in *low_history){
            return -float.infinity;
        }
        auto my_history = new HistoryNode!S(state, low_history);

        if (low_lower_bound > alpha){
            alpha = low_lower_bound;
        }

        if (!children.length){
            make_children;
        }
        float return_value = low_lower_bound;
        bool is_final_value = true;
        foreach (child; children){
            if (alpha >= beta){
                debug (minimax){
                    writeln("Low break with ", alpha, ", ", beta);
                }
                is_final_value = false;
                break;
            }
            auto child_value = -child.minimax_high(&my_history, high_history, -beta, -alpha);
            if (child.high_value.isNaN){
                is_final_value = false;
            }
            else{
                if (-child.high_value > low_lower_bound){
                    low_lower_bound = -child.high_value;
                }
            }
            if (child_value > alpha){
                alpha = child_value;
            }
            if (child_value > return_value)
            {
                return_value = child_value;
            }
        }
        if (is_final_value){
            low_value = low_lower_bound;
            return low_value;
        }
        return return_value;
    }

    float minimax_high(HistoryNode!S *low_history, HistoryNode!S *high_history, float alpha, float beta)
    {
        debug (minimax){
            writeln("High arguments: ", alpha, ", ", beta);
        }
        if (!high_value.isNaN){
            return high_value;
        }
        if (high_history !is null && state in *high_history){
            return float.infinity;
        }
        auto my_history = new HistoryNode!S(state, high_history);

        if (high_lower_bound > alpha){
            alpha = high_lower_bound;
        }

        if (!children.length){
            make_children;
        }
        float return_value = high_lower_bound;
        bool is_final_value = true;
        foreach (child; children){
            if (alpha >= beta){
                debug (minimax){
                    writeln("High break with ", alpha, ", ", beta);
                }
                is_final_value = false;
                break;
            }
            auto child_value = -child.minimax_low(low_history, &my_history, -beta, -alpha);
            if (child.low_value.isNaN){
                is_final_value = false;
            }
            else{
                if (-child.low_value > high_lower_bound){
                    high_lower_bound = -child.low_value;
                }
            }
            if (child_value > alpha){
                alpha = child_value;
            }
            if (child_value > return_value){
                return_value = child_value;
            }
        }
        if (is_final_value){
            high_value = high_lower_bound;
            return high_value;
        }
        return return_value;
    }

    override string toString()
    {
        return format(
            "%s\nlow_value = %s >= %s\nhigh_value = %s >= %s\nnumber of children = %s",
            state,
            low_value, low_lower_bound,
            high_value, high_lower_bound,
            children.length
        );
    }
}

alias ABState8 = ABState!(Board8, CanonicalState8);
