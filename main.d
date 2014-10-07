import std.stdio;
import core.thread;

import board8;
import bit_matrix;
import state;
import game_state;
import search_state;

void print_state(SearchState!Board8 ss){
    writeln(ss.state);
    writeln(ss.player_unconditional);
    writeln(ss.opponent_unconditional);
    //Board8 b;
    //foreach (move; ss.moves){
    //    b |= move;
    //}
    //writeln(b);
    writeln(ss.lower_bound, ", ", ss.upper_bound);
    writeln("Num children:", ss.state.children(ss.moves).length);
    foreach (child; ss.children){
        writeln(" Child: ", child.lower_bound, ", ", child.upper_bound);
    }
    Thread.sleep(dur!("msecs")(1000));
    writeln;
    foreach (child; ss.children){
        if ((ss.state.black_to_play && child.lower_bound == ss.lower_bound) || (!ss.state.black_to_play && child.upper_bound == ss.upper_bound))
            print_state(cast(SearchState!Board8)child);
    }
}


void main()
{
    auto s = State!Board8(rectangle!Board8(4, 1));
    s.player = Board8(1, 0);
    s.opponent = Board8(3, 0);

    Board8 player_unconditional;
    Board8 opponent_unconditional;

    s.analyze_unconditional(player_unconditional, opponent_unconditional);

    assert(!player_unconditional);
    assert(!opponent_unconditional);
    /*
    auto ss = new SearchState!Board8(rectangle!Board8(4, 1));

    ss.state.player = Board8(1, 0);
    ss.state.opponent = Board8(3, 0);

    ss.analyze_unconditional;

    writeln(ss.player_unconditional);
    */

    /*
    ss.calculate_minimax_value(11, -float.infinity);

    print_state(ss);

    writeln(ss.state);
    writeln(ss.lower_bound, ", ", ss.upper_bound);
    */

}
