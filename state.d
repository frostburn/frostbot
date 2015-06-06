module state;

import std.stdio;
import std.string;
import std.stream;

import bit_matrix;
import board_common;
import board8;
import board11;
import pattern3;


struct State(T)
{
    T player;
    T opponent;
    T playing_area = T.full;
    T ko;
    bool black_to_play = true;
    int passes;

    T player_unconditional;
    T opponent_unconditional;
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

    this(T player, T opponent, T playing_area, T ko, bool black_to_play, int passes, T player_unconditional, T opponent_unconditional, float value_shift)
    {
        this.player = player;
        this.opponent = opponent;
        this.playing_area = playing_area;
        this.ko = ko;
        this.black_to_play = black_to_play;
        this.passes = passes;
        this.player_unconditional = player_unconditional;
        this.opponent_unconditional = opponent_unconditional;
        this.value_shift = value_shift;
    }

    invariant
    {
        assert(player.valid);
        assert(opponent.valid);
        assert(playing_area.valid);
        assert(ko.valid);
        assert(ko.popcount <= 1);
        assert(player_unconditional.valid);
        assert(opponent_unconditional.valid);

        assert(!(player & opponent));
        assert(!(player & ko));
        assert(!(opponent & ko));

        assert(!(player & ~playing_area));
        assert(!(opponent & ~playing_area));
        assert(!(ko & ~playing_area));
        assert(!(player_unconditional & ~playing_area));
        assert(!(opponent_unconditional & ~playing_area));

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

    void to_stream(OutputStream stream)
    {
        player.to_stream(stream);
        opponent.to_stream(stream);
        playing_area.to_stream(stream);
        ko.to_stream(stream);
        stream.write(black_to_play ? ~cast(ubyte) 0 : cast(ubyte) 0);
        stream.write(passes);
        player_unconditional.to_stream(stream);
        opponent_unconditional.to_stream(stream);
        stream.write(value_shift);
    }

    static State!T from_stream(InputStream stream)
    {
        T player = T.from_stream(stream);
        T opponent = T.from_stream(stream);
        T playing_area = T.from_stream(stream);
        T ko = T.from_stream(stream);
        ubyte black_to_play;
        stream.read(black_to_play);
        int passes;
        stream.read(passes);
        T player_unconditional = T.from_stream(stream);
        T opponent_unconditional = T.from_stream(stream);
        float value_shift;
        stream.read(value_shift);
        return State!T(player, opponent, playing_area, ko, black_to_play != 0, passes, player_unconditional, opponent_unconditional, value_shift);
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
            (player_unconditional == rhs.player_unconditional) &&
            (opponent_unconditional == rhs.opponent_unconditional) &&
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
        mixin(compare_member("ko"));
        mixin(compare_member("playing_area"));
        mixin(compare_member("player_unconditional"));
        mixin(compare_member("opponent_unconditional"));
        if (value_shift < rhs.value_shift){
            return -1;
        }
        if (value_shift > rhs.value_shift){
            return 1;
        }

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
            player_unconditional.toHash ^
            opponent_unconditional.toHash ^
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
            //Unconditionally alive stones cannot be killed.
            //Having no liberties can happen as a side effect of a reduction.
            if (chains_in_danger[i] & opponent_unconditional){
                continue;
            }
            if (!(chains_in_danger[i].liberties(playing_area & ~player))){
                num_kill += chains_in_danger[i].popcount;
                kill |= chains_in_danger[i];
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

    Pattern3 pattern3_at(in int x, in int y)
    {
        return Pattern3(
            player.pattern3_player_at(x, y),
            opponent.pattern3_player_at(x, y),
            playing_area.pattern3_border_at(x, y)
        );
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

        temp = player_unconditional;
        player_unconditional = opponent_unconditional;
        opponent_unconditional = temp;

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
            if (!(temp & player_unconditional) && !(temp.liberties(playing_area & ~opponent))){
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
        temp = player_unconditional;
        player_unconditional = opponent_unconditional;
        opponent_unconditional = temp;
        black_to_play = !black_to_play;

        return true;
    }

    bool pass()
    {
        return make_move(T());
    }

    State!T[] children(ref T[] moves, bool clear_ko=false)
    {
        State!T[] _children;
        T[] new_moves;

        foreach (move; moves){
            auto child = this;
            if (child.make_move(move)){
                if (clear_ko){
                    child.ko.clear;
                }
                _children ~= child;
                new_moves ~= move;
            }
        }

        moves = new_moves;
        return _children;
    }

    T[] moves()
    {
        T[] _moves;
        auto y_max = playing_area.vertical_extent;
        auto x_max = playing_area.horizontal_extent;
        foreach (y; 0..y_max){
            foreach (x; 0..x_max){
                auto move = T(x, y);
                if (move & playing_area & ~(player_unconditional | opponent_unconditional)){
                    _moves ~= move;
                }
            }
        }
        _moves ~= T();
        return _moves;
    }

    auto children(bool clear_ko=false)
    {
        auto _moves = moves;
        return children(_moves, clear_ko);
    }

    void children_with_pattern3(out State!T[] children, out Pattern3[] patterns)
    {
        for (int y = 0; y < T.HEIGHT; y++){
            for (int x = 0; x < T.WIDTH; x++){
                auto move = T(x, y);
                if (move & playing_area & ~(player_unconditional | opponent_unconditional)){
                    auto child = this;
                    if (child.make_move(move)){
                        children ~= child;
                        patterns ~= pattern3_at(x, y);
                    }
                }
            }
        }
    }

    float liberty_score()
    {
        T player_controlled_territory = (player | player_unconditional) & ~opponent_unconditional;
        T opponent_controlled_territory = (opponent | opponent_unconditional) & ~player_unconditional;

        auto score = player_controlled_territory.popcount;
        score -= opponent_controlled_territory.popcount;

        score += player_controlled_territory.liberties(playing_area & ~opponent_controlled_territory).popcount;
        score -= opponent_controlled_territory.liberties(playing_area & ~player_controlled_territory).popcount;

        if (black_to_play){
            return value_shift + score;
        }
        else{
            return value_shift - score;
        }
    }

    void get_score_bounds(out float lower_bound, out float upper_bound)
    {
        if (is_leaf){
            lower_bound = upper_bound = liberty_score;
            return;
        }
        // Calculate assuming black to play.
        float size = playing_area.popcount;
        version (conservative_bounds){
            lower_bound = -size;
            upper_bound = size;

            // The minimal strategy is to fill half of sure dames.
            auto space = playing_area & ~player & ~opponent;
            int player_crawl = player_unconditional.liberties(space).popcount;
            int opponent_crawl = opponent_unconditional.liberties(space).popcount;

            // TODO: Check if this is right.
            lower_bound += (player_crawl / 2) + (player_crawl & 1);
            upper_bound -= (opponent_crawl / 2); // - (opponent_crawl & 1);

            lower_bound += 2 * player_unconditional.popcount;
            upper_bound -= 2 * opponent_unconditional.popcount;
        }
        else {
            T space = playing_area & ~(player | opponent);
            T player_dames = player_unconditional.liberties(space);
            T opponent_dames = opponent_unconditional.liberties(space);
            int player_dame_count = player_dames.popcount;
            int opponent_dame_count = opponent_dames.popcount;
            int player_pass_sure = player_dame_count / 2;
            int player_sure = player_pass_sure + (player_dame_count & 1);
            int opponent_pass_sure = opponent_dame_count / 2;
            lower_bound = 2 * player_sure - size;
            upper_bound = size - 2 * opponent_pass_sure;
        }

        assert(lower_bound >= -size);
        assert(lower_bound <= size);
        assert(upper_bound >= -size);
        assert(upper_bound <= size);

        if (black_to_play){
            lower_bound += value_shift;
            upper_bound += value_shift;
            if (passes == 1){
                auto score = liberty_score;
                if (score > lower_bound){
                    lower_bound = score;
                }
                if (score > upper_bound){
                    upper_bound = score;
                }
            }
        }
        else {
            auto temp = lower_bound;
            lower_bound = value_shift - upper_bound;
            upper_bound = value_shift - temp;
            if (passes == 1){
                auto score = liberty_score;
                if (score < upper_bound){
                    upper_bound = score;
                }
                if (score < lower_bound){
                    lower_bound = score;
                }
            }
        }
        assert(lower_bound <= upper_bound);
    }

    bool is_leaf()
    {
        return passes >= 2;
    }

    int reduce()
    {
        T space = playing_area & ~player_unconditional & ~opponent_unconditional;
        playing_area = space.cross(playing_area);

        int delta = (player_unconditional & ~playing_area).popcount;
        delta -= (opponent_unconditional & ~playing_area).popcount;

        player &= playing_area;
        opponent &= playing_area;
        ko &= playing_area;
        player_unconditional &= playing_area;
        opponent_unconditional &= playing_area;

        value_shift += delta;
        return delta;
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
        player_unconditional.fix(westwards, northwards);
        opponent_unconditional.fix(westwards, northwards);
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
        player_unconditional.rotate;
        opponent_unconditional.rotate;
    }

    void mirror_d()
    in
    {
        can_rotate;
    }
    body
    {
        player.mirror_d;
        opponent.mirror_d;
        ko.mirror_d;
        playing_area.mirror_d;
        player_unconditional.mirror_d;
        opponent_unconditional.mirror_d;
    }

    void mirror_h()
    {
        player.mirror_h;
        opponent.mirror_h;
        ko.mirror_h;
        playing_area.mirror_h;
        player_unconditional.mirror_h;
        opponent_unconditional.mirror_h;
    }

    void mirror_v()
    {
        player.mirror_v;
        opponent.mirror_v;
        ko.mirror_v;
        playing_area.mirror_v;
        player_unconditional.mirror_v;
        opponent_unconditional.mirror_v;
    }

    // TODO: Canonize hierarchically ie. based on opCmp order.
    void canonize()
    {
        if (!black_to_play){
            flip_colors;
        }
        analyze_unconditional;
        reduce;
        snap;

        auto temp = this;
        enum compare_and_replace = "
            debug (canonize){
                writeln(\"Comparing:\");
                writeln(this);
                writeln(temp);
            }
            if (temp < this){
                debug (canonize){
                    writeln(\"Replacing with current transformation=\", current_transformation);
                }
                this = temp;
            }
        ";
        enum do_mirror_h = "
            temp.mirror_h;
            temp.snap;
        ";
        enum do_mirror_v = "
            temp.mirror_v;
            temp.snap;
        ";
        mixin(do_mirror_v);
        mixin(compare_and_replace);
        mixin(do_mirror_h);
        mixin(compare_and_replace);
        mixin(do_mirror_v);
        mixin(compare_and_replace);
        if (can_rotate){
            temp.mirror_d;  // Diagonal mirror doesn't need snap.
            mixin(compare_and_replace);
            mixin(do_mirror_v);
            mixin(compare_and_replace);
            mixin(do_mirror_h);
            mixin(compare_and_replace);
            mixin(do_mirror_v);
            mixin(compare_and_replace);
        }
    }

    /**
    * Analyzes the state for unconditional life.
    * Pre-calculated unconditional regions that are to be extended.
    */
    void analyze_unconditional()
    in
    {
        assert(!(player_unconditional & opponent_unconditional));
    }
    body
    {
        // Expand unconditional regions.
        player_unconditional.flood_into(player);
        opponent_unconditional.flood_into(opponent);

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

        // Determine unconditional territory of closed regions
        debug (territory){
            writeln("Analyzing unconditional territory:");
            writeln(this);
        }
        foreach (region; (~player_unconditional & playing_area).chains){
            if (region & opponent_unconditional){
                continue;
            }
            auto extended_region = region.cross(playing_area);
            if (
                (extended_region & player_unconditional) &&
                is_unconditional_territory(extended_region, player & region, opponent & region, player_unconditional & extended_region)
            ){
                player_unconditional |= region;
            }
        }
        foreach (region; (~opponent_unconditional & playing_area).chains){
            if (region & player_unconditional){
                continue;
            }
            auto extended_region = region.cross(playing_area);
            if (
                (extended_region & opponent_unconditional) &&
                is_unconditional_territory(extended_region, opponent & region, player & region, opponent_unconditional & extended_region)
            ){
                opponent_unconditional |= region;
            }
        }
    }

    float target_score()
    {
        return 0;
    }

    float player_chain_liberties(T chain)
    {
        if (chain & player_unconditional){
            return float.infinity;
        }
        return chain.liberties(playing_area & ~opponent).popcount;
    }

    float opponent_chain_liberties(T chain)
    {
        if (chain & opponent_unconditional){
            return float.infinity;
        }
        return chain.liberties(playing_area & ~player).popcount;
    }

    string _toString(T player_defendable, T opponent_defendable, T player_secure, T opponent_secure, T mark=T.init)
    {
        //0 - Gray
        //1 - Red
        //2 - Green
        //3 - Yellow
        //4 - Blue
        //5 - Purple
        //6 - Cyan
        //7 - White
        string r;
        T p;
        for (int y = 0; y < playing_area.vertical_extent; y++){
            for(int x = 0; x < playing_area.horizontal_extent; x++){
                p = T(x, y);
                if (playing_area & p){
                    r ~= "\x1b[0;30;";
                    if (player_secure & p){
                        if (opponent & p){
                            // Red
                            r ~= "41m";
                        }
                        else{
                            // Green
                            r ~= "42m";
                        }
                    }
                    else if (opponent_secure & p){
                        if (player & p){
                            // Red
                            r ~= "41m";
                        }
                        else{
                            // Green
                            r ~= "42m";
                        }
                    }
                    else if ((player_defendable | opponent_defendable) & p){
                        // Blue
                        r ~= "44m";
                    }
                    else if (mark & p){
                        // Cyan
                        r ~= "46m";
                    }
                    else{
                        // Yeallow
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

        r ~= format(" passes=%s, value_shift=%s", passes, value_shift);

        return r;
    }

    string toString()
    {
        return _toString(T(), T(), player_unconditional, opponent_unconditional);
    }

    string repr()
    {
        return format(
            "State!%s(%s, %s, %s, %s, %s, %s, %s, %s, %s)", T.stringof,
            player.repr, opponent.repr,
            playing_area.repr, ko.repr,
            black_to_play, passes,
            player_unconditional.repr, opponent_unconditional.repr,
            value_shift
        );
    }
}

alias State8 = State!Board8;
alias State11 = State!Board11;

void benson(T)(ref T[] chains, ref T[] regions, in T opponent, in T immortal, in T playing_area)
{
    // A combination matrix that holds both the information of
    // if region i is vital to chain j and
    // if region i is the neighbour of chain j
    // stacked on top of each other.
    // Two virtual regions provide liberties for immortal chains.
    auto chain_count = chains.length;
    auto region_count = regions.length;
    auto region_count_plus = region_count;
    if (immortal){
        region_count_plus += 2;
    }
    if (region_count_plus < 2){
        chains = chains.init;
        regions = regions.init;
        return;
    }
    BitMatrix is_vital__is_neighbour = BitMatrix(region_count_plus, 2 * chain_count);

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
        if (chain & immortal){
            is_vital__is_neighbour.set(region_count, j);
            is_vital__is_neighbour.set(region_count + 1, j);
        }
    }

    bool recheck;
    do{
        recheck = false;
        foreach (j; 0..chain_count){
            auto vital_count = is_vital__is_neighbour.row_popcount(j);
            if (vital_count < 2){
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

bool can_become_seki(T)(T chain, T liberties)
{
    if (chain.popcount != 2){
        return false;
    }

    auto count = liberties.popcount;
    if (count == 6){
        return true;
    }
    else if (count == 5){
        return liberties.chains.length == 4;
    }
    else if(count == 4){
        if (liberties.chains.length == 4){
            return !(liberties & liberties.north(2) || liberties & liberties.east(2));
        }
        else {
            return false;
        }
    }
    return false;
}

// NOTE: Allows for huge kills that might not actually count.
// If the the ruleset demands that all removable stones must be removed then
// it might be possible for the invader to live under the removed stones.
// Under weird rulesets it may be even possible to live in seki while in atari.
bool is_unconditional_territory(T)(T region, T player, T opponent, T player_unconditional)
{
    // return false;
    debug (territory){
        writeln("Arguments:");
        writeln("region");
        writeln(region);
        writeln("player");
        writeln(player);
        writeln("opponent");
        writeln(opponent);
        writeln("player_unconditional");
        writeln(player_unconditional);
    }
    foreach (chain; player.chains){
        auto liberties = chain.liberties(region & ~opponent);
        assert(!(liberties & player_unconditional));
        // A chain migh be weak enough for the area to become seki.
        if (can_become_seki(chain, liberties)){
            continue;
        }
        // Otherwise the chain reduces the eyespace or is big enough to capture to get eyes.
        player ^= chain;
        opponent |= liberties;
    }
    debug (territory){
        writeln("After initial kills:");
        writeln("player");
        writeln(player);
        writeln("opponent");
        writeln(opponent);
    }
    opponent |= player_unconditional.liberties(region);
    debug (territory){
        writeln("After filling the border:");
        writeln(opponent);
    }
    auto inside = region & ~player_unconditional;
    foreach (chain; opponent.chains){
        while (true){
            chain.flood_into(opponent);
            debug (territory){
                writeln("Crawling with:");
                writeln(chain);
            }
            auto liberties = chain.liberties(inside);
            auto true_liberties = liberties & ~player;
            auto count = true_liberties.popcount;
            T capturing_stone;
            bool is_double_capture = false;
            bool is_recapturable;
            if (count == 1){
                capturing_stone = true_liberties;
                foreach (piece; [capturing_stone.north, capturing_stone.east, capturing_stone.west, capturing_stone.south]){
                    if (piece & (chain | ~opponent)){
                        continue;
                    }
                    auto other_chain = piece.flood_into(opponent);
                    if (other_chain.liberties(inside & ~player).popcount == 1){
                        is_double_capture = true;
                        break;
                    }
                }
                is_recapturable = !capturing_stone.liberties(player) && capturing_stone.liberties(chain).popcount == 1;
            }
            if (count == 0){
                auto kill = liberties & player;
                kill.flood_into(player);
                if (!kill){
                    assert(!player);
                    assert(opponent == inside);
                    debug (territory){
                        writeln("Crawling left no liberties:");
                        writeln(opponent);
                    }
                    return true;
                }
                player ^= kill;
                opponent |= kill.liberties(region);
            }
            // If capturing this chain leads to recapture then life in double ko or moonshine life may be possible.
            else if (count == 1 && (is_double_capture || !is_recapturable)){
                opponent |= true_liberties;
            }
            else {
                debug (territory){
                    writeln("Crawl break:");
                }
                break;
            }
            debug (territory){
                writeln("Crawled:");
                writeln(opponent);
            }
        }
    }
    debug (territory){
        writeln("After crawling:");
        writeln("player");
        writeln(player);
        writeln("opponent");
        writeln(opponent);
    }
    auto eyes = (inside & ~opponent).chains;
    if (eyes.length > 1){
        return false;
    }
    // If we reach here it should mean that there is a single eye
    // that needs to be checked for seki.
    assert(eyes.length == 1);
    auto eye = eyes[0];
    if (!player){
        return eye.popcount < 3;
    }
    assert(player.popcount == 2);
    auto liberties = player.liberties(region & ~opponent);
    if ((player | liberties) != eye){
        return false;
    }
    return !can_become_seki(player, liberties);
}


void examine_state_playout(T)(State!T s, bool canonize=false)
{
    import std.random;
    import core.thread;

    Mt19937 gen;
    gen.seed(2345678);

    int j = 0;
    while (j < 80){
        auto children = s.children;
        auto n = gen.front;
        gen.popFront;
        s = children[n % children.length];
        if (canonize){
            s.canonize;
        }
        writeln(s);
        /*
        writeln("children");
        foreach (child; children){
            writeln(child);
        }
        */
        //Thread.sleep(dur!("msecs")(1000));
        j++;
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

    invariant
    {
        assert(state.black_to_play);
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

    int passes(int value) @property
    {
        state.passes = value;
        state.canonize;
        return value;
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

    T player_unconditional() const @property
    {
        return state.player_unconditional;
    }

    T opponent_unconditional() const @property
    {
        return state.opponent_unconditional;
    }

    float value_shift() const @property
    {
        return state.value_shift;
    }

    float value_shift(float shift) @property
    {
        state.value_shift = shift;
        return shift;
    }

    float liberty_score()
    {
        return state.liberty_score;
    }

    void get_score_bounds(out float lower_bound, out float upper_bound)
    {
        state.get_score_bounds(lower_bound, upper_bound);
    }

    void swap_turns()
    {
        state.swap_turns;
        state.canonize;
    }

    void pass()
    {
        state.pass;
        state.canonize;
    }

    T[] moves()
    {
        return state.moves;
    }

    CanonicalState!T[] children(bool clear_ko=false)
    {
        auto moves = state.moves;
        return children(moves, clear_ko);
    }

    CanonicalState!T[] children(ref T[] moves, bool clear_ko=false)
    {
        CanonicalState!T[] _children;
        bool[CanonicalState!T] seen;
        foreach (child; state.children(moves, clear_ko)){
            auto canonical_child = CanonicalState!T(child);
            if (canonical_child !in seen){
                seen[canonical_child] = true;
                _children ~= canonical_child;
            }
        }
        return _children;
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

    string _toString(T player_defendable, T opponent_defendable, T player_secure, T opponent_secure, T mark=T.init)
    {
        return state._toString(player_defendable, opponent_defendable, player_secure, opponent_secure, mark);
    }

    string toString()
    {
        return state.toString;
    }

    string repr()
    {
        return format("CanonicalState!%s(%s)", T.stringof, state.repr);
    }
}

alias CanonicalState8 = CanonicalState!Board8;
alias CanonicalState11 = CanonicalState!Board11;


State!T decanonize(T)(State!T parent, State!T child)
{
    foreach (child_; parent.children){
        auto canonical_child = child_;
        canonical_child.canonize;
        if (child == canonical_child){
            return child_;
        }
    }
    assert(false);
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

    s.analyze_unconditional;
    assert(s.player_unconditional == (s.player | Board8(0, 0) | Board8(1, 1)));
    assert(!s.opponent_unconditional);

    s.player |= Board8(5, 6);
    s.analyze_unconditional;
    assert(s.opponent_unconditional == (s.opponent | Board8(5, 6) | Board8(6, 6) | Board8(7, 5)));

    s = State!Board8(rectangle!Board8(4, 1));
    s.player = Board8(1, 0);
    s.opponent = Board8(3, 0);

    s.analyze_unconditional;

    assert(s.player_unconditional == s.playing_area);
    assert(!s.opponent_unconditional);
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

unittest
{
    auto s = State8(rectangle8(2, 1));
    s.player = Board8(0, 0);
    s.player_unconditional = Board8(0, 0);
    assert(s.make_move(Board8(1, 0)));
    s.canonize;
    assert(!s.playing_area);
    assert(s.value_shift == -2);
}

unittest
{
    auto inside = Board8(0, 0) | Board8(1, 0) | Board8(2, 0) | Board8(0, 1) | Board8(1, 1) | Board8(0, 2);
    auto playing_area = inside.cross(full8);
    auto player_unconditional = inside.liberties(playing_area);
    // The state would be unconditional territory in global search,
    // but locally white could make Moonshine Life.
    // auto s = State8(playing_area);
    // s.player = player_unconditional;
    // s.player_unconditional = player_unconditional;
    // writeln(s);
    // s.canonize;
    assert(!is_unconditional_territory(playing_area, Board8(), Board8(), player_unconditional));
}

unittest
{
    // TODO: Turn into proper unittests.
    /*
    auto playing_area = rectangle11(9, 9);
    auto eyespace = (rectangle11(6, 7).south(2) | Board11(6, 3) | Board11(6, 4)) & ~(rectangle11(3, 2).south(4).east(2) | rectangle11(3, 2).south(6).east(1) | Board11(5, 7) | Board11(5, 8) | Board11(0, 2));
    auto player = playing_area & ~(Board11(7, 1) | Board11(8, 6) | Board11(7, 8) | Board11(2, 6) | Board11(3, 5) | eyespace);
    player |= Board11(3, 8);  // Without this the invader lives with a multi-headed dragon.
    auto opponent = player.liberties(playing_area) & eyespace;
    opponent |= Board11(0, 4); // Without this the invader makes an eye and lives in moonshine.
    auto s = State11(playing_area);
    s.player = player;
    s.opponent = opponent;
    s.analyze_unconditional;
    writeln(s);
    */

    /*
    auto area = rectangle8(6, 5);
    auto defender = Board8(2, 2) | Board8(3, 2);
    auto space = defender.cross(area) | Board8(1, 1);
    auto invader = space.cross(area).cross(area);
    auto defender_unconditional = area & ~invader;
    invader &= ~defender_unconditional;
    defender |= defender_unconditional;
    invader &= ~space;
    auto s = State8(area);
    s.player = defender;
    s.player_unconditional = defender_unconditional;
    s.opponent = invader;
    s.analyze_unconditional;
    writeln(s);
    */
}

unittest
{
    State8 s;
    s.player = Board8(1, 0) | Board8(2, 0) | Board8(2, 1);
    s.player |= Board8(0, 1) | Board8(0, 2) | Board8(1, 2);

    s.opponent = Board8(7, 6);
    s.opponent |= Board8(7, 4) | Board8(6, 4) | Board8(6, 5) | Board8(5, 5) | Board8(4, 5) | Board8(4, 6);

    s.analyze_unconditional;

    auto stream = new MemoryStream;
    s.to_stream(stream);
    stream.position = 0;
    auto c = State8.from_stream(stream);
    assert(s == c);
}
