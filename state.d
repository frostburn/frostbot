module state;

import std.stdio;
import std.string;


struct State(T)
{
    T player;
    T opponent;
    T playing_area = full8;
    T ko;
    bool black_to_play = true;
    int passes;

    this(T playing_area)
    {
        this.playing_area = playing_area;
    }

    this(T player, T opponent)
    {
        this.player = player;
        this.opponent = opponent;
    }

    this(T player, T opponent, T playing_area, T ko, bool black_to_play, int passes)
    {
        this.player = player;
        this.opponent = opponent;
        this.playing_area = playing_area;
        this.ko = ko;
        this.black_to_play = black_to_play;
        this.passes = passes;
    }

    invariant
    {
        assert(player.valid);
        assert(opponent.valid);
        assert(playing_area.valid);
        assert(ko.valid);
        assert(ko.popcount <= 1);

        assert(!(player & opponent));
        assert(!(player & ko));
        assert(!(opponent & ko));

        assert(!(player & ~playing_area));
        assert(!(opponent & ~playing_area));
        assert(!(ko & ~playing_area));
    }

    bool opEquals(in State!T rhs) const
    {
        return (
            (player == rhs.player) &&
            (opponent == rhs.opponent) &&
            (playing_area == rhs.playing_area) &&
            (ko == rhs.ko) &&
            (black_to_play == rhs.black_to_play) &&
            (passes == rhs.passes)
        );
    }

    hash_t toHash() const nothrow @safe
    {
        hash_t opponent_hash = opponent.toHash;
        return (
            player.toHash ^
            (opponent_hash << (hash_t.sizeof * 4)) ^
            (opponent_hash >> (hash_t.sizeof * 4)) ^
            playing_area.toHash ^
            ko.toHash ^
            typeid(black_to_play).getHash(&black_to_play) ^
            typeid(passes).getHash(&passes)
        );
    }

    /// Kill opponent's stones with a move by player
    private int kill_stones(in T move)
    {
        int num_chains = 0;
        int num_kill = 0;
        T kill;
        T killer_liberties = move.liberties(playing_area);
        T temp, temp_opponent;
        T[4] chains_in_danger;

        // Check for possible chains in the four directions.
        temp_opponent = opponent;

        string get_chain_and_reduce(string direction){
            return "
                temp = move." ~ direction ~ ";
                if (temp & opponent){
                    chains_in_danger[num_chains++] = temp.flood_into(temp_opponent);
                    temp_opponent ^= temp;
                }
            ";
        }

        mixin(get_chain_and_reduce("east"));
        mixin(get_chain_and_reduce("west"));
        mixin(get_chain_and_reduce("south"));
        mixin(get_chain_and_reduce("north"));

        debug(kill_stones) {
            writeln("Chains in danger:");
            foreach (chain; chains_in_danger){
                writeln(chain);
                writeln("");
            }
        }

        for (int i = 0; i < num_chains; i++){
            debug(kill_stones){
                writefln("Liberties: %s", i);
                writeln(chains_in_danger[i].liberties(playing_area & ~player));
            }
            if (!(chains_in_danger[i].liberties(playing_area & ~player))){
                num_kill += chains_in_danger[i].popcount;
                kill |= chains_in_danger[i];
                temp = chains_in_danger[i];
            }
        }

        opponent ^= kill;

        //Ko occurs when one stone is killed and the killing stone is left alone in atari.
        if (
            (num_kill == 1) &&
            !(killer_liberties & player) &&
            ((killer_liberties & ~opponent).popcount == 1)
        ){
            ko = temp;
        }
        else{
            ko.clear;
        }

        debug(kill_stones) writefln("Number of stones killed: %s", num_kill);

        return num_kill;
    }

    void flip_colors()
    {
        T temp = player;
        player = opponent;
        opponent = temp;
        black_to_play = !black_to_play;
    }

    bool make_move(in T move)
    {
        T old_ko = ko;
        T temp = move;
        if (move){
            if ((move & player) || (move & opponent) || (move & ko))
                return false;
            player |= move;
            kill_stones(move);
            temp.flood_into(player);
            // Check if move is suicidal and undo it if necessary.
            if (!(temp.liberties(playing_area & ~opponent))){
                player ^= move;
                ko = old_ko;
                return false;
            }
            passes = 0;
        }
        // Pass
        else{
            if (ko){  // Clearing a ko is treated specially.
                ko.clear;
            }
            else{
                passes++;
            }
        }

        temp = player;
        player = opponent;
        opponent = temp;
        black_to_play = !black_to_play;

        return true;
    }

    State!T[] children(T[] moves)
    {
        State!T[] _children = [];

        foreach (move; moves){
            auto child = this;
            if (child.make_move(move)){
                _children ~= child;
            }
        }

        return _children;
    }

    auto children()
    {
        T[] moves;
        for (int y = 0; y < T.HEIGHT; y++){
            for (int x = 0; x < T.WIDTH; x++){
                moves ~= T(x, y);
            }
        }
        moves ~= T();

        return children(moves);
    }

    int liberty_score()
    {
        int score = 0;

        score += player.popcount;
        score -= opponent.popcount;

        score += player.liberties(playing_area & ~opponent).popcount;
        score -= opponent.liberties(playing_area & ~player).popcount;

        if (black_to_play){
            return score;
        }
        else{
            return -score;
        }
    }

    string toString()
    {
        string r;
        T p;
        for (int y = 0; y < T.HEIGHT; y++){
            for(int x = 0; x < T.WIDTH; x++){
                p = T(x, y);
                if (playing_area & p){
                    r ~= "\x1b[0;30;43m";
                }
                else{
                    r ~= "\x1b[0m";
                }

                if ((black_to_play && (player & p)) || (!black_to_play && (opponent & p))){
                    r ~= "\x1b[30m" ~ "● ";
                }
                else if ((black_to_play && (opponent & p)) || (!black_to_play && (player & p))){
                    r ~= "\x1b[37m" ~ "● ";
                }
                else if (ko & p){
                    r ~= "\x1b[30m" ~ "□ ";
                }
                else{
                    r ~= "  ";
                }
            }
            r ~= "\x1b[0m";
            r ~= "\n";
        }

        if (black_to_play){
            r ~= "Black to play,";
        }
        else{
            r ~= "White to play,";
        }

        r ~= format(" passes=%s", passes);

        return r;
    }
}

unittest
{
    auto s = State!Board8(
        Board8(0, 1),
        Board8(0, 0),
    );
    assert(s.black_to_play);
    s.make_move(Board8(1, 0));
    assert(s.player == empty8);
    assert(s.opponent == (Board8(0, 1) | Board8(1, 0)));
    assert(s.playing_area == full8);
    assert(s.ko == empty8);
    assert(!s.black_to_play);
}

unittest
{
    auto s = State!Board8(
        Board8(0, 1),
        Board8(0, 0) | Board8(2, 0) | Board8(1, 1)
    );
    s.make_move(Board8(1, 0));
    assert(!(s.player & Board8(0, 0)));
    assert(s.ko == Board8(0, 0));
    auto player = s.player;
    auto opponent = s.opponent;
    auto ko = s.ko;
    auto black_to_play = s.black_to_play;
    assert(!s.make_move(Board8(0, 0)));
    assert(s.player == player);
    assert(s.opponent == opponent);
    assert(s.ko == ko);
    assert(s.black_to_play == black_to_play);
    s.make_move(Board8(5, 5));
    assert(!s.ko);
}

void examine_state_playout()
{
    import std.random;
    import core.thread;

    auto s = State!Board8();
    bool success;
    int i = 0;
    int j = 0;
    while (j < 1000){
        success = s.make_move(Board8(
            uniform(0, Board8.WIDTH), uniform(0, Board8.HEIGHT)
        ));
        if (success){
            i++;
            j = 0;
            writeln(s);
            Thread.sleep(dur!("msecs")(250));
        }
        else{
            j++;
        }
    }
}
