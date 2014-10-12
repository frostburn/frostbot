module defense_state;

import std.stdio;
import std.string;

import polyomino;
import board8;
import state;


struct DefenseState(T)
{
    T player;
    T opponent;
    T playing_area = T(T.FULL);
    T ko;
    T player_target;
    T opponent_target;
    T player_outside_liberties;
    T opponent_outside_liberties;
    bool black_to_play = true;
    int passes;
    float ko_threats = 0;

    this(T playing_area)
    {
        this.playing_area = playing_area;
    }

    this(T player, T opponent)
    {
        this.player = player;
        this.opponent = opponent;
    }

    this(T player, T opponent, T playing_area, T ko, T player_target, T opponent_target, T player_outside_liberties, T opponent_outside_liberties, bool black_to_play, int passes, float ko_threats)
    {
        this.player = player;
        this.opponent = opponent;
        this.playing_area = playing_area;
        this.ko = ko;
        this.player_target = player_target;
        this.opponent_target = opponent_target;
        this.player_outside_liberties = player_outside_liberties;
        this.opponent_outside_liberties = opponent_outside_liberties;
        this.black_to_play = black_to_play;
        this.passes = passes;
        this.ko_threats = ko_threats;
    }

    /*
    invariant
    {
        assert(player.valid);
        assert(opponent.valid);
        assert(playing_area.valid);
        assert(ko.valid);
        assert(ko.popcount <= 1);
        assert(player_target.valid);
        assert(opponent_target.valid);
        assert(player_outside_liberties.valid);
        assert(opponent_outside_liberties.valid);

        assert(!(player & opponent));
        assert(!(player & ko));
        assert(!(opponent & ko));
        assert(!(player & opponent_outside_liberties));
        assert(!(opponent & player_outside_liberties));
        assert(!(player_target & opponent_target));
        assert(!(player_target & player_outside_liberties));
        assert(!(player_target & opponent_outside_liberties));
        assert(!(opponent_target & player_outside_liberties));
        assert(!(opponent_target & opponent_outside_liberties));
        assert(!(player_outside_liberties & opponent_outside_liberties));

        assert(!(player & ~playing_area));
        assert(!(opponent & ~playing_area));
        assert(!(ko & ~playing_area));
        assert(!(player_target & ~playing_area));
        assert(!(opponent_target & ~playing_area));
        assert(!(player_outside_liberties & ~playing_area));
        assert(!(opponent_outside_liberties & ~playing_area));


        // TODO: Assert that all killable chains have liberties.
        version(all_invariants){
            foreach (player_chain; player.chains){
                assert(player_chain & player_outside_liberties || player_chain.liberties(playing_area & ~opponent));
            }
            foreach (opponent_chain; opponent.chains){
                assert(opponent_chain & opponent_outside_liberties || opponent_chain.liberties(playing_area & ~player));
            }
        }
    }
    */

    bool opEquals(in DefenseState!T rhs) const
    {
        return (
            (player == rhs.player) &&
            (opponent == rhs.opponent) &&
            (playing_area == rhs.playing_area) &&
            (ko == rhs.ko) &&
            (player_target == rhs.player_target) &&
            (opponent_target == rhs.opponent_target) &&
            (player_outside_liberties == rhs.player_outside_liberties) &&
            (opponent_outside_liberties == rhs.opponent_outside_liberties) &&
            (black_to_play == rhs.black_to_play) &&
            (passes == rhs.passes) &&
            (ko_threats == rhs.ko_threats)
        );
    }

    int opCmp(in DefenseState!T rhs) const
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
        mixin(compare_member("ko"));
        mixin(compare_member("player_target"));
        mixin(compare_member("opponent_target"));
        mixin(compare_member("player_outside_liberties"));
        mixin(compare_member("opponent_outside_liberties"));
        if (ko_threats < rhs.ko_threats){
            return -1;
        }
        if (ko_threats > rhs.ko_threats){
            return 1;
        }
        mixin(compare_member("playing_area"));

        return 0;
    }

    hash_t toHash() const nothrow @safe
    {
        hash_t opponent_hash = opponent.toHash;
        hash_t player_target_hash = player_target.toHash;
        return (
            player.toHash ^
            (opponent_hash << (hash_t.sizeof * 4)) ^
            (opponent_hash >> (hash_t.sizeof * 4)) ^
            playing_area.toHash ^
            ko.toHash ^
            (player_target_hash << (hash_t.sizeof * 4)) ^
            (player_target_hash >> (hash_t.sizeof * 4)) ^
            opponent_target.toHash ^
            player_outside_liberties.toHash ^
            opponent_outside_liberties.toHash ^
            typeid(black_to_play).getHash(&black_to_play) ^
            typeid(passes).getHash(&passes) ^
            typeid(ko_threats).getHash(&ko_threats)
        );
    }

    T free_space() const
    {
        return (playing_area & ~player & ~opponent);
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
            if (!(chains_in_danger[i] & opponent_outside_liberties) && !(chains_in_danger[i].liberties(playing_area & ~player))){
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
    }

    void swap_turns()
    {
        auto temp = player;
        player = opponent;
        opponent = temp;

        temp = player_target;
        player_target = opponent_target;
        opponent_target = temp;

        temp = player_outside_liberties;
        player_outside_liberties = opponent_outside_liberties;
        opponent_outside_liberties = temp;

        ko_threats = -ko_threats;
        black_to_play = !black_to_play;
    }

    bool make_move(in T move)
    {
        T old_ko = ko;
        T temp = move;
        if (move){
            if ((move & player) || (move & opponent) || (move & opponent_outside_liberties))
                return false;
            if (move & ko){
                if (ko_threats > 0){
                    ko_threats -= 1;
                }
                else{
                    return false;
                }
            }
            player |= move;
            kill_stones(move);
            temp.flood_into(player);
            // Check if move is suicidal and undo it if necessary.
            if (!(temp & player_outside_liberties) && !(temp.liberties(playing_area & ~opponent))){
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

        swap_turns;

        return true;
    }

    DefenseState!T[] children(T[] moves)
    {
        DefenseState!T[] _children = [];

        foreach (move; moves){
            //TODO: These sould be one per chain.
            /*
            if (move & player_outside_liberties){
                if (liberty_taking_move_played){
                    continue;
                }
                else{
                    liberty_taking_move_played = true;
                }
            }
            */
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

    // TODO: Canonization
    /*
    void snap()
    {
        int westwards, northwards;
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
        snap;
    }

    void mirror_h()
    {
        player.mirror_h;
        opponent.mirror_h;
        ko.mirror_h;
        playing_area.mirror_h;
        snap;
    }

    void mirror_v()
    {
        player.mirror_v;
        opponent.mirror_v;
        ko.mirror_v;
        playing_area.mirror_v;
        snap;
    }


    // TODO: Canonize hierarchically ie. based on opCmp order.
    void canonize()
    {
        if (!black_to_play){
            flip_colors;
        }
        snap;
        auto temp = this;
        enum compare_and_replace = "
            if (temp < this){
                this = temp;
            }
        ";
        if (can_rotate){
            for (int i = 0; i < 3; i++){
                temp.rotate;
                mixin(compare_and_replace);
            }
            temp.mirror_h;
            mixin(compare_and_replace);
            for (int i = 0; i < 3; i++){
                temp.rotate;
                mixin(compare_and_replace);
            }
        }
        else{
            temp.mirror_v;
            mixin(compare_and_replace);
            temp.mirror_h;
            mixin(compare_and_replace);
            temp.mirror_v;
            mixin(compare_and_replace);
        }
    }
    */

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
        // Add immortal stones to unconditionally controlled territory.
        T tmp = player_outside_liberties;
        tmp.flood_into(player);
        player_unconditional |= tmp;
        tmp = opponent_outside_liberties;
        tmp.flood_into(opponent);
        opponent_unconditional |= tmp;

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

    string _toString(T player_defendable, T opponent_defendable, T player_secure, T opponent_secure)
    {
        string r;
        T p;
        for (int y = 0; y < playing_area.vertical_extent; y++){
            for(int x = 0; x < playing_area.horizontal_extent; x++){
                p = T(x, y);
                if (playing_area & p){
                    r ~= "\x1b[0;30;";
                    if (player_outside_liberties & p){
                        r ~= "45m";
                    }
                    else if (opponent_outside_liberties & p){
                        r ~= "46m";
                    }
                    else if (player_target & p){
                        r ~= "44m";
                    }
                    else if (opponent_target & p){
                        r ~= "41m";
                    }
                    else if ((player_defendable | opponent_defendable | player_secure | opponent_secure) & p){
                        r ~= "42m";
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

        r ~= format(" passes=%s, ko_threats=%s", passes, ko_threats);

        return r;
    }

    string toString(){
        return _toString(T(), T(), T(), T());
    }
}

alias DefenseState8 = DefenseState!Board8;


bool eyespace_fits(T)(Eyespace eyespace)
{
    return (
        (eyespace.west_extent >= 0) &&
        (eyespace.north_extent >= 0) &&
        (eyespace.east_extent < T.WIDTH) &&
        (eyespace.south_extent < T.HEIGHT)
    );
}


DefenseState!T from_eyespace(T)(Eyespace eyespace, bool defender_to_play=true, float ko_threats=0)
in
{
    assert(eyespace.west_extent >= 0);
    assert(eyespace.north_extent >= 0);
    assert(eyespace.east_extent < T.WIDTH);
    assert(eyespace.south_extent < T.HEIGHT);
}
body
{
    T space = from_shape!T(eyespace.space);
    T edge = from_shape!T(eyespace.edge);

    T player;
    T opponent;

    if (defender_to_play){
        player = edge;
    }
    else{
        opponent = edge;
    }

    return DefenseState!T(player, opponent, space | edge, T(), player, opponent, T(), T(), true, 0, ko_threats);
}


alias eyespace_fits8 = eyespace_fits!Board8;
alias from_eyespace8 = from_eyespace!Board8;

unittest
{
    auto s = DefenseState8();
    s.opponent = s.playing_area & ~Board8(0, 0);
    s.opponent_outside_liberties = s.opponent;

    assert(!s.make_move(Board8(0, 0)));
    assert(s.make_move(Board8()));
    assert(s.make_move(Board8(0, 0)));
    assert(s.opponent == s.playing_area);

    s = DefenseState8();
    s.opponent = Board8(0, 0);
    s.opponent_outside_liberties = s.opponent;
    s.player = Board8(1, 0);

    assert(s.make_move(Board8(0, 1)));
    assert(s.player == Board8(0, 0));
    assert(s.opponent == (Board8(1, 0) | Board8(0, 1)));
}