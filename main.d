import std.stdio;
import core.thread;

import utils;
import board8;
import bit_matrix;
import state;
import polyomino;
import defense_state;
import game_state;
import search_state;
import defense_search_state;
import defense;

/*
void print_state(SearchState!Board8 ss, int depth){
    //
    //writeln(ss.player_unconditional);
    //writeln(ss.opponent_unconditional);
    //Board8 b;
    //foreach (move; ss.moves){
    //    b |= move;
    //}
    //writeln(b);
    if (depth <= 0){
        return;
    }
    if (ss.is_leaf && ss.lower_bound != ss.upper_bound){
        writeln(ss.state);
        writeln(ss.lower_bound, ", ", ss.upper_bound);
        writeln("Num children:", ss.children.length);
        foreach (child; ss.children){
            writeln(" Child: ", child.lower_bound, ", ", child.upper_bound);
        }
        Thread.sleep(dur!("msecs")(1000));
        writeln;
    }
    foreach (child; ss.children){
        //if ((ss.state.black_to_play && child.lower_bound == ss.lower_bound) || (!ss.state.black_to_play && child.upper_bound == ss.upper_bound))
            print_state(cast(SearchState!Board8)child, depth - 1);
    }
}
*/


void main()
{
    DefenseState8 s;
    auto space = rectangle8(5, 1).south.east;
    auto opponent = rectangle8(7, 3) & ~space;

    s.playing_area = space | opponent;
    s.opponent = opponent;
    s.opponent_target = opponent;

    writeln(s);
    writeln(s.calculate_status8);

    /*
    foreach (eyespace; eyespaces(6).byKey){
        if (!eyespace_fits8(eyespace)){
            eyespace.rotate;
            eyespace.snap;
            if (!eyespace_fits8(eyespace)){
                continue;
            }
        }
        DefenseState8 s = from_eyespace8(eyespace, false, float.infinity);
        auto ds = new DefenseSearchState8(s);
        ds.calculate_minimax_value;
        if (ds.upper_bound < float.infinity){
            writeln(ds);
            writeln;
        }
    }
    */
}
