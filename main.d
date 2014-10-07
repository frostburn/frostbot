import std.stdio;

import board8;
import state;
import game_state;
import bit_matrix;

void main()
{
    //auto gs = new GameState!Board8(rectangle!Board8(4, 1));
    //auto gs = new GameState!Board8(rectangle!Board8(2, 2));
    //gs.calculate_minimax_value(false);
    //writeln(gs);

    /*
    auto gs = new GameState!Board8(rectangle!Board8(4, 1));
    gs.state.player = Board8(1, 0);
    gs.state.opponent = Board8(2, 0);
    */

    /*
    auto gs = new GameState!Board8(rectangle!Board8(3, 3));
    gs.calculate_minimax_value(true);
    writeln(gs);
    */

    /*
    foreach (child; 
        gs.children){
        writeln("Child: ", &child);
        writeln(child);
        foreach (grandchild; child.children){
            writeln("Grandchild: ", &grandchild);
            writeln(grandchild);
        }
    }
    assert(gs.children[0].state == gs.children[$ - 1].children[1].state);
    assert((gs.children[0]) is (gs.children[$ - 1].children[1]));
    */

    State!Board8 s;
    s.player = Board8(1, 0) | Board8(2, 0) | Board8(2, 1);
    s.player |= Board8(0, 1) | Board8(0, 2) | Board8(1, 2);

    s.opponent = Board8(7, 6);
    s.opponent |= Board8(7, 4) | Board8(6, 4) | Board8(6, 5) | Board8(5, 5) | Board8(4, 5) | Board8(4, 6);

    Board8 player_unconditional;
    Board8 opponent_unconditional;

    s.analyze_unconditional(player_unconditional, opponent_unconditional);
    assert(player_unconditional == (s.player | Board8(0, 0) | Board8(1, 1)));
    assert(!opponent_unconditional);

    s.player |= Board8(5, 6);
    s.analyze_unconditional(player_unconditional, opponent_unconditional);
    assert(opponent_unconditional == (s.opponent | Board8(5, 6) | Board8(6, 6) | Board8(7, 5)));


    writeln(s);

    writeln(player_unconditional);
    writeln;
    writeln(opponent_unconditional);
}
