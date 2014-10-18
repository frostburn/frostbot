import std.stdio;
import core.thread;

import utils;
import board8;
import bit_matrix;
import state;
import polyomino;
import defense_state;
import game_state;
//import search_state;
import defense_search_state;
import defense;
import eyeshape;

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

/*
void print_path(SearchState8 ss, int depth){
    if (depth <= 0){
        return;
    }
    writeln(ss);
    writeln(ss.player_useless | ss.opponent_useless);
    foreach (child; ss.children){
        writeln(" ", child.lower_bound, ", ", child.upper_bound, ", max=", child.state.black_to_play);
    }
    bool found_one = false;
    foreach (child; ss.children){
        if (-child.lower_bound == ss.upper_bound && -child.upper_bound == ss.lower_bound){
            print_path(cast(SearchState8)child, depth - 1);
            found_one = true;
            break;
        }
    }
    if (!found_one){
        foreach (child; ss.children){
            if (-child.upper_bound == ss.lower_bound){
                print_path(cast(SearchState8)child, depth - 1);
                break;
            }
        }
    }
}
*/

void main()
{
    writeln("main");

    Transposition[DefenseState8] empty;
    auto defense_transposition_table = &empty;


    auto ds = new DefenseSearchState8(rectangle8(4, 3), defense_transposition_table);
    //ss.state.opponent = Board8(1, 0);
    ds.iterative_deepening_search(30);

    ds.ppp;

    /+
    Transposition[DefenseState8] defense_transposition_table;

    foreach (eyespace; eyespaces(4).byKey){
        if (eyespace.space.length == 4){
            auto s = from_eyespace8(eyespace, false, -float.infinity);
            if (s.opponent_targets.length){
                s.opponent_targets[0].outside_liberties = 1;
            }
            auto ds = new DefenseSearchState8(s);
            ds.calculate_minimax_value;
            if (ds.lower_bound == ds.upper_bound){
                //writeln(s);
                //writeln(ds.lower_bound);
            }
            else{
                //writeln(ds);
            }
            /*
            Board8[] creating_moves;
            auto cs = s.children_and_moves(creating_moves);
            foreach (index, c; cs){
                auto cds = new DefenseSearchState8(c);
                cds.calculate_minimax_value;
                writeln(creating_moves[index]);
                writeln(cds.upper_bound);
            }
            */
        }
    }
    +/
}
