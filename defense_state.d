module defense_state;

import std.stdio;
import std.string;

import utils;
import polyomino;
import board8;
import state;


struct TargetChain(T)
{
    T chain;
    float outside_liberties = 0;

    this(T chain)
    {
        this.chain = chain;
    }

    this(T chain, float outside_liberties)
    {
        this.chain = chain;
        this.outside_liberties = outside_liberties;
    }

    invariant
    {
        assert(chain.valid);
        assert(chain);
        assert(outside_liberties >= 0);
    }

    bool opEquals(in TargetChain!T rhs) const pure nothrow @nogc @safe
    {
        return chain == rhs.chain && outside_liberties == rhs.outside_liberties;
    }

    int opCmp(in TargetChain!T rhs) const pure nothrow @nogc @safe
    {
        if (chain != rhs.chain){
            return chain.opCmp(rhs.chain);
        }
        if (outside_liberties < rhs.outside_liberties){
            return -1;
        }
        if (outside_liberties > rhs.outside_liberties){
            return 1;
        }
        return 0;
    }

    hash_t toHash() const nothrow @safe
    {
        return (
            chain.toHash ^
            typeid(outside_liberties).getHash(&outside_liberties)
        );
    }
}

alias TargetChain8 = TargetChain!Board8;

struct DefenseState(T)
{
    T player;
    T opponent;
    T playing_area = T.full;
    T ko;
    TargetChain!T[] player_targets;
    TargetChain!T[] opponent_targets;
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

    this(T player, T opponent, T playing_area, T ko, TargetChain!T[] player_targets, TargetChain!T[] opponent_targets, bool black_to_play, int passes, float ko_threats)
    {
        this.player = player;
        this.opponent = opponent;
        this.playing_area = playing_area;
        this.ko = ko;
        this.player_targets = player_targets.dup;
        this.player_targets.sort;
        this.opponent_targets = opponent_targets.dup;
        this.opponent_targets.sort;
        this.black_to_play = black_to_play;
        this.passes = passes;
        this.ko_threats = ko_threats;
    }

    T player_target() const @property
    {
        T result;
        foreach (target; player_targets){
            result |= target.chain;
        }
        return result;
    }

    T opponent_target() const @property
    {
        T result;
        foreach (target; opponent_targets){
            result |= target.chain;
        }
        return result;
    }

    void player_target(T chain) @property
    {
        auto target_chain = TargetChain!T(chain);
        player_targets = [target_chain];
    }

    void opponent_target(T chain) @property
    {
        auto target_chain = TargetChain!T(chain);
        opponent_targets = [target_chain];
    }

    DefenseState!T opAssign(DefenseState!T rhs)
    {
        this.player = rhs.player;
        this.opponent = rhs.opponent;
        this.playing_area = rhs.playing_area;
        this.ko = rhs.ko;
        this.player_targets = rhs.player_targets.dup;
        this.opponent_targets = rhs.opponent_targets.dup;
        this.black_to_play = rhs.black_to_play;
        this.passes = rhs.passes;
        this.ko_threats = rhs.ko_threats;

        return this;
    }

    this(this)
    {
        player_targets = player_targets.dup;
        opponent_targets = opponent_targets.dup;
    }

    invariant
    {
        assert(player.valid);
        assert(opponent.valid);
        assert(playing_area.valid);
        assert(ko.valid);
        assert(ko.popcount <= 1);
        //assert(player_target.valid);
        //assert(opponent_target.valid);

        /*
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
        */

        // TODO: Assert that all killable chains have liberties.
        /*
        version(all_invariants){
            foreach (player_chain; player.chains){
                assert(player_chain & player_outside_liberties || player_chain.liberties(playing_area & ~opponent));
            }
            foreach (opponent_chain; opponent.chains){
                assert(opponent_chain & opponent_outside_liberties || opponent_chain.liberties(playing_area & ~player));
            }
        }
        */
    }

    bool opEquals(in DefenseState!T rhs) const
    {
        return (
            (player == rhs.player) &&
            (opponent == rhs.opponent) &&
            (playing_area == rhs.playing_area) &&
            (ko == rhs.ko) &&
            (player_targets == rhs.player_targets) &&
            (opponent_targets == rhs.opponent_targets) &&
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

        if (player_targets != rhs.player_targets){
            return compare_sorted_lists!(TargetChain!T)(player_targets, rhs.player_targets);
        }
        if (opponent_targets != rhs.opponent_targets){
            return compare_sorted_lists!(TargetChain!T)(opponent_targets, rhs.opponent_targets);
        }

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
        hash_t player_targets_hash = typeid(player_targets).getHash(&player_targets);
        return (
            player.toHash ^
            (opponent_hash << (hash_t.sizeof * 4)) ^
            (opponent_hash >> (hash_t.sizeof * 4)) ^
            playing_area.toHash ^
            ko.toHash ^
            (player_targets_hash << (hash_t.sizeof * 4)) ^
            (player_targets_hash >> (hash_t.sizeof * 4)) ^
            typeid(opponent_targets).getHash(&opponent_targets) ^
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
            auto chain_in_danger = chains_in_danger[i];
            float chain_outside_liberties = 0;
            foreach (opponent_target; opponent_targets){
                if (opponent_target.chain & chain_in_danger){
                    chain_outside_liberties += opponent_target.outside_liberties;
                }
            }
            if (!(chain_outside_liberties) && !(chain_in_danger.liberties(playing_area & ~player))){
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

        auto targets_temp = player_targets;
        player_targets = opponent_targets;
        opponent_targets = targets_temp;

        ko_threats = -ko_threats;
        black_to_play = !black_to_play;
    }

    bool make_move(in T move)
    {
        T old_ko = ko;
        T temp = move;
        if (move){
            if ((move & player) || (move & opponent))
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
            bool has_liberties = bool(temp.liberties(playing_area & ~opponent));
            if (!has_liberties){
                foreach (player_target; player_targets){
                    if (temp & player_target.chain){
                        if (player_target.outside_liberties){
                            has_liberties = true;
                            break;
                        }
                    }
                }
            }
            if (!has_liberties){
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

    void fill_opponent_outside_liberty(size_t index)
    in
    {
        assert(index < opponent_targets.length);
        assert(opponent_targets[index].outside_liberties);
    }
    body
    {
        opponent_targets[index].outside_liberties -= 1;
        opponent_targets.sort;
        swap_turns;
    }

    DefenseState!T[] children(T[] moves)
    {
        DefenseState!T[] _children = [];

        foreach (move; moves){
            auto child = this;
            if (child.make_move(move)){
                _children ~= child;
            }
        }

        foreach (index, opponent_target; opponent_targets){
            auto child = this;
            if (opponent_target.outside_liberties){
                child.fill_opponent_outside_liberty(index);
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
        // Outside liberties are not counted towards or against the score.
        if (player_target & ~player){
            if (black_to_play){
                return -float.infinity;
            }
            else{
                return float.infinity;
            }
        }
        if (opponent_target & ~opponent){
            if (black_to_play){
                return float.infinity;
            }
            else{
                return -float.infinity;
            }
        }

        float score = 0;

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
        return (passes >= 2 || player_target & ~player || opponent_target & ~opponent);
    }

    /// Applies reducing transformations that do not affect the result.
    int reduce()
    {
        float[T] liberties_by_chain;

        string normalize_targets(string player)
        {
            return "
                foreach (ref " ~ player ~ "_target; " ~ player ~ "_targets){
                    if (" ~ player ~ "_target.chain & " ~ player ~ "){
                        " ~ player ~ "_target.chain.flood_into(" ~ player ~ ");
                    }
                    if (" ~ player ~ "_target.chain in liberties_by_chain){
                        liberties_by_chain[" ~ player ~ "_target.chain] += " ~ player ~ "_target.outside_liberties;
                    }
                    else{
                        liberties_by_chain[" ~ player ~ "_target.chain] = " ~ player ~ "_target.outside_liberties;
                    }
                }
                " ~ player ~ "_targets = " ~ player ~ "_targets.init;
                foreach (chain, liberties; liberties_by_chain){
                    " ~ player ~ "_targets ~= TargetChain8(chain, liberties);
                }
                " ~ player ~ "_targets.sort;
            ";
        }

        mixin(normalize_targets("player"));
        liberties_by_chain = liberties_by_chain.init;
        mixin(normalize_targets("opponent"));

        if ((cast(bool)player_targets.length) ^ (cast(bool)opponent_targets.length)){
            string reduce_target(string player)
            {
                return "
                    T space = playing_area & ~" ~ player ~ "_target;
                    T blob = space.blob(playing_area);
                    foreach (ref " ~ player ~ "_target; " ~ player ~ "_targets){
                        T candidate_" ~ player ~ "_chain = " ~ player ~ "_target.chain & blob;
                        if (candidate_" ~ player ~ "_chain.chains.length == " ~ player ~ "_target.chain.chains.length){
                            " ~ player ~ "_target.chain = candidate_" ~ player ~ "_chain;
                        }
                    }
                    " ~ player ~ "_targets.sort;
                    int old_size = playing_area.popcount;
                    playing_area = space | " ~ player ~ "_target;
                    player &= playing_area;
                    opponent &= playing_area;
                    int new_size = playing_area.popcount;
                ";
            }

            if (player_targets.length){
                mixin(reduce_target("player"));
                return old_size - new_size;
            }
            else{
                mixin(reduce_target("opponent"));
                return new_size - old_size;
            }
        }
        else{
            return 0;
        }
    }

    void snap(out int westwards, out int northwards)
    {
        playing_area.snap(westwards, northwards);
        player.fix(westwards, northwards);
        opponent.fix(westwards, northwards);
        ko.fix(westwards, northwards);

        string fix_targets(string player){
            return "
                foreach (ref " ~ player ~ "_target; " ~ player ~ "_targets){
                    " ~ player ~ "_target.chain.fix(westwards, northwards);
                }
                " ~ player ~ "_targets.sort;
            ";
        }

        mixin(fix_targets("player"));
        mixin(fix_targets("opponent"));
    }

    bool can_rotate()
    {
        return playing_area.can_rotate;
    }

    static string transform_targets(string player, string transform){
        return "
            foreach (ref " ~ player ~ "_target; " ~ player ~ "_targets){
                " ~ player ~ "_target.chain." ~ transform ~ ";
            }
            " ~ player ~ "_targets.sort;
        ";
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
        mixin(transform_targets("player", "rotate"));
        mixin(transform_targets("opponent", "rotate"));
    }

    void mirror_h()
    {
        player.mirror_h;
        opponent.mirror_h;
        ko.mirror_h;
        playing_area.mirror_h;
        mixin(transform_targets("player", "mirror_h"));
        mixin(transform_targets("opponent", "mirror_h"));
    }

    void mirror_v()
    {
        player.mirror_v;
        opponent.mirror_v;
        ko.mirror_v;
        playing_area.mirror_v;
        mixin(transform_targets("player", "mirror_v"));
        mixin(transform_targets("opponent", "mirror_v"));
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
        // Add immortal stones to unconditionally controlled territory.

        string add_immortal_chains(string player){
            return "
                foreach (" ~ player ~ "_target; " ~ player ~ "_targets){
                    if (" ~ player ~ "_target.outside_liberties == float.infinity){
                        T temp = " ~ player ~ "_target.chain;
                        temp.flood_into(" ~ player ~ ");
                        " ~ player ~ "_unconditional |= temp;
                    }
                }
            ";
        }
        mixin(add_immortal_chains("player"));
        mixin(add_immortal_chains("opponent"));

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
                    if (player_target & p){
                        r ~= "45m";
                    }
                    else if (opponent_target & p){
                        r ~= "41m";
                    }
                    else if ((player_secure | opponent_secure) & p){
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

        float total_player_outside_liberties = 0;
        foreach (player_target; player_targets){
            total_player_outside_liberties += player_target.outside_liberties;
        }
        float total_opponent_outside_liberties = 0;
        foreach (opponent_target; opponent_targets){
            total_opponent_outside_liberties += opponent_target.outside_liberties;
        }

        r ~= format(
            " passes=%s, ko_threats=%s, player liberties=%s, opponent liberties=%s",
            passes, ko_threats, total_player_outside_liberties, total_opponent_outside_liberties
        );

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

    TargetChain8[] player_targets;
    TargetChain8[] opponent_targets;

    if (defender_to_play){
        player = edge;
        player_targets ~= TargetChain8(player);
    }
    else{
        opponent = edge;
        opponent_targets ~= TargetChain8(opponent);
    }

    return DefenseState!T(player, opponent, space | edge, T(), player_targets, opponent_targets, true, 0, ko_threats);
}


alias eyespace_fits8 = eyespace_fits!Board8;
alias from_eyespace8 = from_eyespace!Board8;

unittest
{
    auto s = DefenseState8();
    s.opponent = s.playing_area & ~Board8(0, 0);
    s.opponent_target = s.opponent;
    s.opponent_targets[0].outside_liberties = float.infinity;

    assert(!s.make_move(Board8(0, 0)));
    assert(s.make_move(Board8()));
    assert(s.make_move(Board8(0, 0)));
    assert(s.opponent == s.playing_area);

    s = DefenseState8();
    s.opponent = Board8(0, 0);
    s.opponent_target = s.opponent;
    s.opponent_targets[0].outside_liberties = float.infinity;
    s.player = Board8(1, 0);

    assert(s.make_move(Board8(0, 1)));
    assert(s.player == Board8(0, 0));
    assert(s.opponent == (Board8(1, 0) | Board8(0, 1)));
}