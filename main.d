import std.stdio;
import core.thread;

import board8;
import bit_matrix;
import state;
import game_state;
import search_state;

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


void main()
{
    auto pa = rectangle!Board8(3, 3) | Board8(3, 0);
    auto ss = new SearchState!Board8(pa);

    //ss.iterative_deepening_search(30, 90);
    ss.calculate_minimax_value(7);

    //print_state(ss, 50);
    writeln(ss.state);
    writeln(ss.lower_bound, ", ", ss.upper_bound);

    /*
    HistoryNode!(State!Board8) parent_h = null;

    auto s = State!Board8();
    auto h = new HistoryNode!(State!Board8)(s, parent_h);

    auto child_s = s;
    child_s.player = Board8(3, 3);
    auto child_h = new HistoryNode!(State!Board8)(child_s, h);

    //writeln(s in parent_h);
    writeln(child_s in h);
    writeln(child_s in child_h);
    writeln(s in child_h);
    */

    /*
    auto gs = new GameState!Board8(rectangle!Board8(3, 3));

    gs.calculate_minimax_value(false);
    writeln(gs);
    */

}
