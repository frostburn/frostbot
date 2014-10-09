import std.stdio;
import core.thread;

import board8;
import bit_matrix;
import state;
import game_state;
import search_state;
import defense_state;

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
    //auto pa = rectangle!Board8(3, 3) | Board8(3, 0);
    //auto ss = new SearchState!Board8(pa);

    auto s = State8();
    s.player = rectangle8(8, 4) & ~rectangle8(4, 3) & ~Board8(6, 0) & ~Board8(7, 1) & ~Board8(4, 0);
    s.player |= rectangle8(5, 2).south(5) & ~rectangle8(4, 1).south(6);
    s.opponent = rectangle8(4, 3) & ~rectangle8(3, 2);
    s.opponent |= rectangle8(8, 3).south(4) & ~rectangle8(5, 2).south(5);
    s.opponent &= ~Board8(6, 6) & ~Board8(7, 5);
    auto ds = new DefenseState8(s, s.player, s.opponent);

    ds.calculate_minimax_value;
    //assert(ds.lower_bound == 6);
    //assert(ds.upper_bound == 6);

    //print_state(ss, 50);
    writeln(ds.state);
    writeln(ds.lower_bound, ", ", ds.upper_bound);

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
