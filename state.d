module state;

import std.stdio;
import std.string;

import bit_matrix;
import board8;


struct State(T)
{
    T player;
    T opponent;
    T playing_area = T.full;
    T ko;
    bool black_to_play = true;
    int passes;
    float value_shift = 0;

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

        /*
        assert(!(player & opponent));
        assert(!(player & ko));
        assert(!(opponent & ko));

        assert(!(player & ~playing_area));
        assert(!(opponent & ~playing_area));
        assert(!(ko & ~playing_area));
        */

        // TODO: Assert that all chains have liberties
        version(all_invariants){
            foreach (player_chain; player.chains){
                assert(player_chain.liberties(playing_area & ~opponent));
            }
            foreach (opponent_chain; opponent.chains){
                assert(opponent_chain.liberties(playing_area & ~player));
            }
        }
    }

    bool opEquals(in State!T rhs) const
    {
        return (
            (player == rhs.player) &&
            (opponent == rhs.opponent) &&
            (playing_area == rhs.playing_area) &&
            (ko == rhs.ko) &&
            (black_to_play == rhs.black_to_play) &&
            (passes == rhs.passes) &&
            (value_shift == rhs.value_shift)
        );
    }

    int opCmp(in State!T rhs) const
    {
        string compare_member(string member){
            return "
                if (" ~ member ~ " != rhs." ~ member ~ "){
                    return " ~ member ~".opCmp(rhs." ~ member ~ ");
                }
            ";
        }

        mixin(compare_member("player"));
        mixin(compare_member("opponent"));
        if (black_to_play < rhs.black_to_play){
            return -1;
        }
        if (black_to_play > rhs.black_to_play){
            return 1;
        }
        if (passes != rhs.passes){
            return passes - rhs.passes;
        }
        if (value_shift < rhs.value_shift){
            return -1;
        }
        if (value_shift > rhs.value_shift){
            return 1;
        }
        mixin(compare_member("ko"));
        mixin(compare_member("playing_area"));

        return 0;
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
            typeid(passes).getHash(&passes) ^
            typeid(value_shift).getHash(&value_shift)
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
            ko = kill;
        }
        else{
            ko.clear;
        }

        debug(kill_stones) writefln("Number of stones killed: %s", num_kill);

        return num_kill;
    }

    void flip_colors()
    {
        black_to_play = !black_to_play;
        value_shift = -value_shift;
    }

    void swap_turns()
    {
        auto temp = player;
        player = opponent;
        opponent = temp;

        black_to_play = !black_to_play;
    }

    bool make_move(in T move)
    in
    {
        assert(!move || move & playing_area);
    }
    body
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
                auto move = T(x, y);
                if (move & playing_area){
                    moves ~= move;
                }
            }
        }
        moves ~= T();

        return children(moves);
    }

    float liberty_score()
    {
        float score = value_shift;

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

    bool is_leaf()
    {
        return passes >= 2;
    }

    int reduce()
    {
        return 0;
    }

    void snap()
    {
        int w, n;
        snap(w, n);
    }

    void snap(out int westwards, out int northwards)
    {
        playing_area.snap(westwards, northwards);
        player.fix(westwards, northwards);
        opponent.fix(westwards, northwards);
        ko.fix(westwards, northwards);
    }

    bool can_rotate()
    {
        return playing_area.can_rotate;
    }

    void rotate()
    in
    {
        can_rotate;
    }
    body
    {
        player.rotate;
        opponent.rotate;
        ko.rotate;
        playing_area.rotate;
    }

    void mirror_h()
    {
        player.mirror_h;
        opponent.mirror_h;
        ko.mirror_h;
        playing_area.mirror_h;
    }

    void mirror_v()
    {
        player.mirror_v;
        opponent.mirror_v;
        ko.mirror_v;
        playing_area.mirror_v;
    }

    void canonize()
    {
        int dummy_w, dummy_n;
        canonize(dummy_w, dummy_n);
    }

    // TODO: Canonize hierarchically ie. based on opCmp order.
    Transformation canonize(out int final_westwards, out int final_northwards)
    {
        if (!black_to_play){
            flip_colors;
        }
        auto initial_playing_area = playing_area;  // TODO: Calculate fixes manually

        auto final_transformation = Transformation.none;
        auto current_transformation = Transformation.none;
        snap(final_westwards, final_northwards);
        auto temp = this;
        enum compare_and_replace = "
            debug(canonize){
                writeln(\"Comparing:\");
                writeln(this);
                writeln(temp);
            }
            if (temp < this){
                debug(canonize) {
                    writeln(\"Replacing with current transformation=\", current_transformation);
                }
                final_transformation = current_transformation;
                this = temp;
            }
        ";
        enum do_rotation = "
            temp.rotate;
            temp.snap(final_westwards, final_northwards);
        ";
        enum do_mirror_v = "
            temp.mirror_v;
            temp.snap(final_westwards, final_northwards);
        ";
        if (can_rotate){
            for (int i = 0; i < 3; i++){
                mixin(do_rotation);
                current_transformation++;
                mixin(compare_and_replace);
            }

            mixin(do_mirror_v);
            current_transformation++;
            mixin(compare_and_replace);

            for (int i = 0; i < 3; i++){
                mixin(do_rotation);
                current_transformation++;
                mixin(compare_and_replace);
            }
        }
        else{
            mixin(do_mirror_v);
            current_transformation = Transformation.mirror_v;
            mixin(compare_and_replace);

            temp.mirror_h;
            temp.snap(final_westwards, final_northwards);
            current_transformation = Transformation.flip;
            mixin(compare_and_replace);
            
            mixin(do_mirror_v);
            current_transformation = Transformation.mirror_h;
            mixin(compare_and_replace);
        }

        initial_playing_area.transform(final_transformation);
        initial_playing_area.snap(final_westwards, final_northwards);

        return final_transformation;
    }

    /**
    * Analyzes the state for unconditional life.
    * The arguments provide pre-calculated unconditional regions that are to be extended.
    */
    void analyze_unconditional(ref T player_unconditional, ref T opponent_unconditional)
    in
    {
        assert(!(player_unconditional & opponent_unconditional));
    }
    body
    {
        // The unconditional regions are already analyzed and can be excluded here.
        T[] player_chains = player.chains;
        T[] player_enclosed_regions = (~player & ~player_unconditional & playing_area).chains;
        T[] opponent_chains = opponent.chains;
        T[] opponent_enclosed_regions = (~opponent & ~opponent_unconditional & playing_area).chains;

        T[] temp;
        // Prune out regions that are already controlled by the other player.
        foreach (player_enclosed_region; player_enclosed_regions){
            if (!(player_enclosed_region & opponent_unconditional)){
                temp ~= player_enclosed_region;
            }
        }
        player_enclosed_regions = temp;

        temp = [];
        foreach (opponent_enclosed_region; opponent_enclosed_regions){
            if (!(opponent_enclosed_region & player_unconditional)){
                temp ~= opponent_enclosed_region;
            }
        }
        opponent_enclosed_regions = temp;

        // Prune out the rest using Benson's algorithm.
        benson(player_chains, player_enclosed_regions, opponent, player_unconditional, playing_area);
        benson(opponent_chains, opponent_enclosed_regions, player, opponent_unconditional, playing_area);

        // Extend the uncoditionally controlled regions.
        foreach (player_chain; player_chains){
            player_unconditional |= player_chain;
        }
        foreach (opponent_chain; opponent_chains){
            opponent_unconditional |= opponent_chain;
        }
        foreach (player_enclosed_region; player_enclosed_regions){
            player_unconditional |= player_enclosed_region;
        }
        foreach (opponent_enclosed_region; opponent_enclosed_regions){
            opponent_unconditional |= opponent_enclosed_region;
        }
    }

    float target_score()
    {
        return 0;
    }

    float player_chain_liberties(T chain)
    {
        return chain.liberties(playing_area & ~opponent).popcount;
    }

    float opponent_chain_liberties(T chain)
    {
        return chain.liberties(playing_area & ~player).popcount;
    }

    string _toString(T player_defendable, T opponent_defendable, T player_secure, T opponent_secure)
    {
        string r;
        T p;
        for (int y = 0; y < playing_area.vertical_extent; y++){
            for(int x = 0; x < playing_area.horizontal_extent; x++){
                p = T(x, y);
                if (playing_area & p){
                    r ~= "\x1b[0;30;";
                    if ((player_secure | opponent_secure) & p){
                        r ~= "42m";
                    }
                    else if ((player_defendable | opponent_defendable) & p){
                        r ~= "44m";
                    }
                    else{
                        r ~= "43m";
                    }
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

    string toString(){
        return _toString(T(), T(), T(), T());
    }
}

alias State8 = State!Board8;

void benson(T)(ref T[] chains, ref T[] regions, in T opponent, in T immortal, in T playing_area)
{
    // A combination matrix that holds both the information of
    // if region i is vital to chain j and
    // if region i is the neighbour of chain j
    // stacked on top of each other.
    auto chain_count = chains.length;
    BitMatrix is_vital__is_neighbour = BitMatrix(regions.length, 2 * chain_count);

    foreach (j, chain; chains){
        T chain_liberties = chain.liberties(playing_area);
        T far_empty_intersections = ~opponent & ~ chain_liberties;
        foreach (i, region; regions){
            T empty_intersections = region & ~opponent;
            T region_far_empty_intersections = region & far_empty_intersections;
            if (empty_intersections && !region_far_empty_intersections){
                is_vital__is_neighbour.set(i, j);
            }
            if (region & chain_liberties){
                is_vital__is_neighbour.set(i, j + chain_count);
            }
        }
    }

    bool recheck;
    do{
        recheck = false;
        foreach (j, chain; chains){
            auto vital_count = is_vital__is_neighbour.row_popcount(j);
            if (vital_count < 2 && !(chain & immortal)){
                recheck = recheck || is_vital__is_neighbour.clear_columns_by_row(j + chain_count);
            }
        }
    }while (recheck);

    T[] temp;
    foreach (j, chain; chains){
        // Clear neighbours so that dead regions won't choke up on them.
        is_vital__is_neighbour.clear_row(j + chain_count);
        if (is_vital__is_neighbour.row_nonzero(j)){
            temp ~= chain;
        }
    }
    chains = temp;

    temp = [];
    foreach (i, region; regions){
        if (is_vital__is_neighbour.column_nonzero(i)){
            temp ~= region;
        }
    }
    regions = temp;
}

void examine_state_playout(bool canonize=false)
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
            if (canonize){
                auto t = s;
                t.canonize;
                writeln(t);
            }
            else{
                writeln(s);
            }
            Thread.sleep(dur!("msecs")(1000));
        }
        else{
            j++;
        }
    }
}


struct CanonicalState(T)
{
    State!T state;

    this(T playing_area)
    {
        this(State!T(playing_area));
    }

    this(State!T state)
    {
        state.canonize;
        this.state = state;
    }

    bool opEquals(in CanonicalState!T rhs) const pure nothrow
    {
        return state == rhs.state;
    }

    int opCmp(in CanonicalState!T rhs) const pure nothrow
    {
        return state.opCmp(rhs.state);
    }

    hash_t toHash() const nothrow @safe
    {
        return state.toHash;
    }

    int passes() const @property
    {
        return state.passes;
    }

    bool is_leaf()
    {
        return state.is_leaf;
    }

    T playing_area() const @property
    {
        return state.playing_area;
    }

    T player() const @property
    {
        return state.player;
    }

    T opponent() const @property
    {
        return state.opponent;
    }

    T ko() const @property
    {
        return state.ko;
    }

    bool black_to_play() const @property
    {
        return state.black_to_play;
    }

    float value_shift() const @property
    {
        return state.value_shift;
    }

    float liberty_score()
    {
        return state.liberty_score;
    }

    void swap_turns(){
        state.swap_turns;
    }

    CanonicalState!T[] children(T[] moves)
    {
        CanonicalState!T[] _children;
        bool[CanonicalState!T] seen;
        foreach (child; state.children(moves)){
            auto canonical_child = CanonicalState!T(child);
            if (canonical_child !in seen){
                seen[canonical_child] = true;
                _children ~= canonical_child;
            }
        }
        return _children;
    }

    void analyze_unconditional(ref T player_unconditional, ref T opponent_unconditional)
    {
        state.analyze_unconditional(player_unconditional, opponent_unconditional);
    }

    float target_score()
    {
        return state.target_score;
    }

    float player_chain_liberties(T chain)
    {
        return state.player_chain_liberties(chain);
    }

    float opponent_chain_liberties(T chain)
    {
        return state.opponent_chain_liberties(chain);
    }

    string _toString(T player_defendable, T opponent_defendable, T player_secure, T opponent_secure)
    {
        return state._toString(player_defendable, opponent_defendable, player_secure, opponent_secure);
    }

    string toString()
    {
        return state.toString;
    }
}

alias CanonicalState8 = CanonicalState!Board8;


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
    State8 s;
    s.playing_area = rectangle8(3, 3) | Board8(2, 3);
    s.player = Board8(1, 2) | Board8(2, 2) | Board8(2, 1);
    s.opponent = Board8(0, 0) | Board8(2, 0) | Board8(0, 1) | Board8(1, 1);
    s.passes = 1;
    assert(s.make_move(Board8(1, 0)));
    assert(s.ko);
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

unittest
{
    auto a = State!Board8();
    auto b = a;
    a.player = Board8(1UL);
    assert(a > b);
    b.player = Board8(1UL);
    assert(a == b);
    a.opponent = Board8(2UL);
    assert(a > b);
    a.player = Board8(0UL);
    assert(a < b);
}

unittest
{
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

    player_unconditional = Board8();
    opponent_unconditional = Board8();

    s = State!Board8(rectangle!Board8(4, 1));
    s.player = Board8(1, 0);
    s.opponent = Board8(3, 0);

    s.analyze_unconditional(player_unconditional, opponent_unconditional);

    assert(player_unconditional == s.playing_area);
    assert(!opponent_unconditional);
}

unittest
{
    State!Board8 s;
    s.value_shift = -6.5;
    s.make_move(Board8(0, 0));
    assert(s.value_shift == -6.5);
    assert(!s.black_to_play);
    auto a = s;
    a.value_shift = 0;
    assert(a != s);
    auto c = CanonicalState!Board8(s);
    assert(c.value_shift == 6.5);
    assert(c.black_to_play);
    assert(s.player == c.player);
}