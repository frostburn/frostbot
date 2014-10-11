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
void print_path(SearchState8 ss, int depth){
    if (depth <= 0){
        return;
    }
    writeln(ss);
    foreach (child; ss.children){
        writeln(" ", child.lower_bound, ", ", child.upper_bound, ", max=", child.state.black_to_play);
    }
    foreach (child; ss.children){
        if (child.upper_bound == ss.upper_bound){
            Status[DefenseState8] empty;
            SearchState8 recalculated_child = new SearchState8(child.state, (cast(SearchState8)child).canonical_state, Board8(), Board8(), Board8(), Board8(), empty);
            recalculated_child.calculate_minimax_value(80);
            print_path(recalculated_child, depth - 1);
            break;
        }
    }
}

void main()
{

    auto s = State8(rectangle8(3, 3) | Board8(3, 0));
    s.player = Board8(2, 0);
    s.opponent = Board8(1, 1);
    auto ss = new SearchState8(s);
    //ss.state.player = Board8(1, 1);
    //ss.state.opponent = Board8(1, 0);
    ss.calculate_minimax_value(20);

    //print_path(ss, 20);
    writeln(ss);

    /*
    State8 s;
    s.playing_area = rectangle8(3, 3) | Board8(3, 0);
    s.player = Board8(0, 0) | Board8(0, 1) | Board8(1, 2) | Board8(2, 0);
    s.opponent = Board8(1, 0) | Board8(1, 1) | Board8(2, 1);
    auto c = s;
    c.canonize;
    Status[DefenseState8] empty;
    SearchState8 ss = new SearchState8(s, c, Board8(), Board8(), Board8(), Board8(), empty);

    writeln(ss);
    */
}
