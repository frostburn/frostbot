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

void main()
{
    writeln("main");

    /*
    auto t = Transformation.none;
    writeln(t);
    t++;
    writeln(t);
    */

    /*
    auto s = State8(rectangle8(4, 3));
    //s.player = Board8(2, 0);
    //s.opponent = Board8(1, 1);
    auto ss = new SearchState8(s);
    //ss.state.player = Board8(1, 1);
    //ss.state.opponent = Board8(1, 0);
    ss.calculate_minimax_value(20);

    print_path(ss, 20);
    //writeln(ss);
    */


    //writeln(b);

    //auto s = State8(rectangle8(3, 3));
    //s.player = Board8(1, 2) | Board8(2, 2) | Board8(2, 1);
    //s.opponent = rectangle8(4, 2) & ~Board8(2, 1) & ~Board8(3, 0);


    SearchState8[State8] state_pool;
    DefenseResult8[DefenseState8] defense_table;
    //auto ss = new SearchState8(rectangle8(4, 3));

    /*
    ss.make_children(state_pool, defense_table);

    writeln("SSSSSSSSSS");
    writeln(ss);

    foreach (child; ss.children){
        writeln(child);
        writeln;
    }
    */

    auto s = DefenseState8(rectangle8(4, 3));
    s.player = rectangle8(4, 3) & ~rectangle8(3, 2) | Board8(2, 1);
    s.player_target = s.player;
    s.ko_threats = -float.infinity;

    auto gs = new DefenseGameState8(s);

    gs.calculate_minimax_value;

    assert(gs.low_value == 12);
    assert(gs.high_value == 12);
    foreach (child; gs.children){
        assert(child.value_shift < 0);
    }

    foreach (g; gs.principal_path!"high"(20)){
        writeln(g);
    }

    /*
    foreach (child; gs.children){
        writeln("Child:");
        writeln(child);
        foreach (grand_child; child.children){
            writeln("Grandchild");
            writeln(grand_child);
        }
    }*/

    /*
    auto ss = new SearchState8(rectangle8(3, 3));

    ss.calculate_minimax_value(30);
    print_path(ss, 20);
    */



    /*
    auto s = DefenseState8(rectangle8(4, 4));
    s.opponent = Board8(1, 1) | Board8(2, 1);
    s.opponent_target = s.opponent;
    s.player = Board8(1, 2) | Board8(2, 2);
    s.player_target = s.player;
    s.opponent |= Board8(0, 2);
    s.player |= Board8(3, 1);

    writeln(s);

    auto ds = new DefenseSearchState8(s);

    ds.calculate_minimax_value(40);

    writeln(ds);
    */


    /*
    auto s = State8(rectangle8(4, 3));
    s.opponent = rectangle8(4, 3) & ~(Board8(0, 1) | Board8(1, 1) | Board8(1, 2) | Board8(3, 2));
    s.player = Board8(1, 1);
    s.passes = 0;
    */

    /*
    auto s = State8(rectangle8(4, 3));
    s.player = rectangle8(3, 3).east & ~rectangle8(2, 2).east(2).south;
    s.opponent = rectangle8(4, 2).south & ~s.player & ~ Board8(3, 2);

    auto ss = new SearchState8(s);

    ss.calculate_minimax_value(20);

    assert(ss.lower_bound == 12);
    assert(ss.upper_bound == 12);

    writeln(ss);
    */
    //writeln(ss.player_useless | ss.opponent_useless);

    /*
    auto s = State8(rectangle8(3, 4));
    s.player = Board8(0, 0) | Board8(1, 0);
    s.opponent = rectangle8(3, 3).south & ~(Board8(0, 2) | Board8(1, 2) | Board8(1, 3));


    auto ss = new SearchState8(s);

    ss.calculate_minimax_value(20);

    assert(ss.lower_bound == -12);
    assert(ss.upper_bound == -12);

    writeln(ss);
    */

    /*
    auto s = State8(rectangle8(3, 3));
    s.player = Board8(1, 0) | Board8(2, 0) | Board8(0, 1) | Board8(0, 2);
    s.opponent = Board8(1, 1) | Board8(2, 1) | Board8(2, 2);
    auto ss = new SearchState8(s);

    ss.analyze_defendable(defense_table);

    writeln(ss);
    */


    /*
    foreach (child; ss.children){
        writeln(child);
        writeln;
    }
    */

    /*
    State8 s;
    s.playing_area = rectangle8(3, 3) | Board8(2, 3);
    s.player = Board8(1, 2) | Board8(2, 2) | Board8(2, 1);
    s.opponent = Board8(0, 0) | Board8(2, 0) | Board8(0, 1) | Board8(1, 1);
    s.passes = 1;
    assert(s.make_move(Board8(1, 0)));
    assert(s.ko);
    //foreach (child; s.children){
    //    writeln(child);
    //}
    //auto ss = new SearchState8(s);
    //Status[DefenseState8] empty;
    //SearchState8 ss = new SearchState8(s, c, Board8(), Board8(), Board8(), Board8(), empty);

    writeln(s);
    */
}
