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
    int outside_liberties = 0;

    this(T chain)
    {
        this.chain = chain;
    }

    this(T chain, int outside_liberties)
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
    T player_immortal;
    T opponent_immortal;
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

    this(T player, T opponent, T playing_area, T ko, T player_immortal, T opponent_immortal, TargetChain!T[] player_targets, TargetChain!T[] opponent_targets, bool black_to_play, int passes, float ko_threats)
    {
        this.player = player;
        this.opponent = opponent;
        this.playing_area = playing_area;
        this.ko = ko;
        this.player_immortal = player_immortal;
        this.opponent_immortal = opponent_immortal;
        this.player_targets = player_targets.dup;
        this.opponent_targets = opponent_targets.dup;
        normalize_targets;
        this.black_to_play = black_to_play;
        this.passes = passes;
        this.ko_threats = ko_threats;
    }

    T player_target() const @property
    {
        T result;
        foreach (ref target; player_targets){
            result |= target.chain;
        }
        return result;
    }

    T opponent_target() const @property
    {
        T result;
        foreach (ref target; opponent_targets){
            result |= target.chain;
        }
        return result;
    }

    T player_target(T chain) @property
    {
        if (chain){
            auto target_chain = TargetChain!T(chain);
            player_targets = [target_chain];
        }
        else{
            player_targets = player_targets.init;
        }
        return chain;
    }

    T opponent_target(T chain) @property
    {
        if (chain){
            auto target_chain = TargetChain!T(chain);
            opponent_targets = [target_chain];
        }
        else{
            opponent_targets = opponent_targets.init;
        }
        return chain;
    }

    int player_outside_liberties() @property
    {
        int result = 0;
        foreach (ref target; player_targets){
            result += target.outside_liberties;
        }
        return result;
    }

    int opponent_outside_liberties() @property
    {
        int result = 0;
        foreach (ref target; opponent_targets){
            result += target.outside_liberties;
        }
        return result;
    }

    int player_outside_liberties(int liberties) @property
    in
    {
        assert(player_targets.length == 1);
    }
    body
    {
        player_targets[0].outside_liberties = liberties;
        return liberties;
    }

    int opponent_outside_liberties(int liberties) @property
    in
    {
        assert(opponent_targets.length == 1);
    }
    body
    {
        opponent_targets[0].outside_liberties = liberties;
        return liberties;
    }


    DefenseState!T opAssign(DefenseState!T rhs)
    {
        this.player = rhs.player;
        this.opponent = rhs.opponent;
        this.playing_area = rhs.playing_area;
        this.ko = rhs.ko;
        this.player_immortal = rhs.player_immortal;
        this.opponent_immortal = rhs.opponent_immortal;
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
        assert(player_immortal.valid);
        assert(opponent_immortal.valid);

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
            (player_immortal == rhs.player_immortal) &&
            (opponent_immortal == rhs.opponent_immortal) &&
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
        mixin(compare_member("player_immortal"));
        mixin(compare_member("opponent_immortal"));

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
        hash_t player_immortal_hash = player_immortal.toHash;
        return (
            player.toHash ^
            (opponent_hash << (hash_t.sizeof * 4)) ^
            (opponent_hash >> (hash_t.sizeof * 4)) ^
            playing_area.toHash ^
            ko.toHash ^
            (player_immortal_hash << (hash_t.sizeof * 4)) ^
            (player_immortal_hash >> (hash_t.sizeof * 4)) ^
            opponent_immortal.toHash ^
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
            
            if (!chain_has_liberties!"opponent"(chains_in_danger[i])){
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

        temp = player_immortal;
        player_immortal = opponent_immortal;
        opponent_immortal = temp;

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
            if (!chain_has_liberties!"player"(temp)){
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

        normalize_targets(false);
        swap_turns;

        return true;
    }

    bool chain_has_liberties(string player_string)(T chain){
        static if (player_string == "player"){
            enum opponent_string = "opponent";
        }
        else{
            enum opponent_string = "player";
        }
        mixin("
            if (chain & " ~ player_string ~ "_immortal){
                return true;
            }
            foreach (target; " ~ player_string ~ "_targets){
                if (target.outside_liberties && chain & target.chain){
                    return true;
                }
            }
            return bool(chain.liberties(playing_area & ~" ~ opponent_string ~ "));
        ");
    }

    float chain_liberties(string player_string)(T chain){
        static if (player_string == "player"){
            enum opponent_string = "opponent";
        }
        else{
            enum opponent_string = "player";
        }
        mixin("
            if (chain & " ~ player_string ~ "_immortal){
                return float.infinity;
            }
            float outside_liberties = 0;
            foreach (target; " ~ player_string ~ "_targets){
                if (chain & target.chain){
                    outside_liberties += target.outside_liberties;
                }
            }
            return outside_liberties + chain.liberties(playing_area & ~" ~ opponent_string ~ ").popcount;
        ");
    }


    bool target_in_atari(string player_string)(){
        static if (player_string == "player"){
            enum opponent_string = "opponent";
        }
        else{
            enum opponent_string = "player";
        }
        mixin("
            foreach (target; " ~ player_string ~ "_targets){
                if (target.outside_liberties < 2){
                    foreach (chain; target.chain.chains){
                        if (target.outside_liberties + chain.liberties(playing_area & ~" ~ opponent_string ~ ").popcount < 2){
                            return true;
                        }
                    }
                }
            }
            return false;
        ");
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
        if (!opponent_targets[index].outside_liberties && !opponent_targets[index].chain.liberties(playing_area & ~player)){
            opponent ^= opponent_targets[index].chain;
        }
        passes = 0;
        ko.clear;
        swap_turns;
    }

    DefenseState!T[] children(T[] moves, out T[] creating_moves)
    {
        creating_moves = creating_moves.init;
        DefenseState!T[] _children;

        foreach (move; moves){
            auto child = this;
            if (child.make_move(move)){
                _children ~= child;
                creating_moves ~= move;
            }
        }

        foreach (index, opponent_target; opponent_targets){
            auto child = this;
            if (opponent_target.outside_liberties > 0){
                child.fill_opponent_outside_liberty(index);
                _children ~= child;
                creating_moves ~= T();
            }
        }

        return _children;
    }

    auto children(T[] moves)
    {
        T[] dummy;
        return children(moves, dummy);
    }

    auto children_and_moves(out T[] creating_moves)
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

        return children(moves, creating_moves);
    }

    auto children()
    {
        T[] dummy;
        return children_and_moves(dummy);
    }

    float liberty_score()
    {
        // Outside liberties are not counted towards or against the score.
        if (player_target & (~player | opponent_immortal)){
            if (black_to_play){
                return -float.infinity;
            }
            else{
                return float.infinity;
            }
        }
        if (opponent_target & (~opponent | player_immortal)){
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
        return passes >= 2 || player_target & (~player | opponent_immortal) || opponent_target & (~opponent | player_immortal);
    }

    void normalize_targets(bool both_players=true){
        int[T] liberties_by_chain;
        TargetChain!T[] temp;

        string normalize_targets_for(string player)
        {
            return "
                foreach (ref " ~ player ~ "_target; " ~ player ~ "_targets){
                    " ~ player ~ "_target.chain.flood_into(" ~ player ~ "_target.chain | " ~ player ~ ");
                }
                temp = " ~ player ~ "_targets.init;
                foreach(ref target; " ~ player ~ "_targets){
                    if (target.chain & ~" ~ player ~ "_immortal){
                        target.chain &= ~" ~ player ~ "_immortal;
                        temp ~= target;
                    }
                }
                foreach (ref " ~ player ~ "_target; temp){
                    if (" ~ player ~ "_target.chain in liberties_by_chain){
                        liberties_by_chain[" ~ player ~ "_target.chain] += " ~ player ~ "_target.outside_liberties;
                    }
                    else{
                        liberties_by_chain[" ~ player ~ "_target.chain] = " ~ player ~ "_target.outside_liberties;
                    }
                }
                " ~ player ~ "_targets = " ~ player ~ "_targets.init;
                foreach (chain, liberties; liberties_by_chain){
                    " ~ player ~ "_targets ~= TargetChain!T(chain, liberties);
                }
                " ~ player ~ "_targets.sort;
            ";
        }
        player_immortal.flood_into(player);
        opponent_immortal.flood_into(opponent);
        mixin(normalize_targets_for("player"));
        if (both_players){
            liberties_by_chain = liberties_by_chain.init;
            mixin(normalize_targets_for("opponent"));
        }
    }

    /// Applies reducing transformations that do not affect the result.
    int reduce()
    {
        debug(reduce){
            writeln("Before reduction:");
            writeln(this);
        }
        string reduce_target(string player, string opponent)
        {
            return "
                T space = playing_area & ~" ~ player ~ "_target & ~" ~ player ~ "_immortal;
                T blob = space.blob(playing_area) & ~" ~ player ~ "_immortal;
                foreach (ref " ~ player ~ "_target; " ~ player ~ "_targets){
                    T candidate_" ~ player ~ "_chain = " ~ player ~ "_target.chain & blob;
                    if (candidate_" ~ player ~ "_chain.chains.length == " ~ player ~ "_target.chain.chains.length){
                        " ~ player ~ "_target.chain = candidate_" ~ player ~ "_chain;
                    }
                }
                " ~ player ~ "_targets.sort;
                " ~ player ~ "_immortal &= (space & ~" ~ opponent ~ "_immortal).liberties(playing_area) | " ~ opponent ~ "_target;
                int old_size = playing_area.popcount;
                playing_area = space | " ~ player ~ "_target | " ~ player ~ "_immortal;
                player &= playing_area;
                opponent &= playing_area;
                " ~ opponent ~ "_immortal &= playing_area;
                int new_size = playing_area.popcount;
            ";
        }

        int reduction = 0;
        if (player_targets.length || player_immortal){
            mixin(reduce_target("player", "opponent"));
            reduction += old_size - new_size;
        }
        if (opponent_targets.length || opponent_immortal){
            mixin(reduce_target("opponent", "player"));
            reduction -= old_size - new_size;
        }
        debug(reduce) {
            writeln("After reduction:");
            writeln(this);
            writeln("reduction=", reduction);
        }

        return reduction;
    }

    void snap(out int westwards, out int northwards)
    {
        playing_area.snap(westwards, northwards);
        player.fix(westwards, northwards);
        opponent.fix(westwards, northwards);
        ko.fix(westwards, northwards);
        player_immortal.fix(westwards, northwards);
        opponent_immortal.fix(westwards, northwards);

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
        player_immortal.rotate;
        opponent_immortal.rotate;
        mixin(transform_targets("player", "rotate"));
        mixin(transform_targets("opponent", "rotate"));
    }

    void mirror_h()
    {
        player.mirror_h;
        opponent.mirror_h;
        ko.mirror_h;
        playing_area.mirror_h;
        player_immortal.mirror_h;
        opponent_immortal.mirror_h;
        mixin(transform_targets("player", "mirror_h"));
        mixin(transform_targets("opponent", "mirror_h"));
    }

    void mirror_v()
    {
        player.mirror_v;
        opponent.mirror_v;
        ko.mirror_v;
        playing_area.mirror_v;
        player_immortal.mirror_v;
        opponent_immortal.mirror_v;
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
    * To simplify reductions unconditional territory is merged into the immortal chain.
    */
    void analyze_unconditional()
    in
    {
        assert(!(player_immortal & opponent_immortal));
    }
    out
    {
        assert(!(player_immortal & opponent_immortal));
    }
    body
    {
        // Add immortal stones to unconditionally controlled territory.
        T player_unconditional = player_immortal;
        T opponent_unconditional = opponent_immortal;

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

        player_immortal = player_unconditional;
        opponent_immortal = opponent_unconditional;

        player |= player_immortal;
        opponent |= opponent_immortal;

        player &= ~opponent_immortal;
        opponent &= ~player_immortal;

        normalize_targets;
    }

    string toString()
    {
        string r;
        T p;
        for (int y = 0; y < playing_area.vertical_extent; y++){
            for(int x = 0; x < playing_area.horizontal_extent; x++){
                p = T(x, y);
                if (playing_area & p){
                    r ~= "\x1b[0;30;";
                    if ((player_immortal | opponent_immortal) & p){
                        r ~= "42m";
                    }
                    else if (player_target & p){
                        r ~= "45m";
                    }
                    else if (opponent_target & p){
                        r ~= "41m";
                    }
                    //else if ((player_defendable | opponent_defendable) & p){
                    //    r ~= "44m";
                    //}
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
            " passes=%s, ko_threats=%s,\nplayer liberties=%s, opponent liberties=%s",
            passes, ko_threats, total_player_outside_liberties, total_opponent_outside_liberties
        );

        return r;
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

    T player_target;
    T opponent_target;

    if (defender_to_play){
        player = edge;
        player_target = player;
    }
    else{
        opponent = edge;
        opponent_target = opponent;
    }

    auto s = DefenseState!T(player, opponent, space | edge, T(), T(), T(), [], [], true, 0, ko_threats);
    s.player_target = player_target;
    s.opponent_target = opponent_target;

    return s;
}


alias eyespace_fits8 = eyespace_fits!Board8;
alias from_eyespace8 = from_eyespace!Board8;

unittest
{
    auto s = DefenseState8();
    s.opponent = s.playing_area & ~Board8(0, 0);
    s.opponent_immortal = s.opponent;

    assert(!s.make_move(Board8(0, 0)));
    assert(s.make_move(Board8()));
    assert(s.make_move(Board8(0, 0)));
    assert(s.opponent == s.playing_area);

    s = DefenseState8();
    s.opponent = Board8(0, 0);
    s.opponent_immortal = s.opponent;
    s.player = Board8(1, 0);

    assert(s.make_move(Board8(0, 1)));
    assert(s.player == Board8(0, 0));
    assert(s.opponent == (Board8(1, 0) | Board8(0, 1)));
}

unittest
{
    auto s = DefenseState8(rectangle8(4, 1));
    s.opponent = Board8(0, 0) | Board8(3, 0);
    s.opponent_target = s.opponent;
    auto rcs = s;
    rcs.reduce;
    rcs.canonize;

    assert(!s.is_leaf);
    s.make_move(Board8(1, 0));
    assert(s.is_leaf);

    assert(!rcs.is_leaf);
    rcs.make_move(Board8(1, 0));
    rcs.reduce;
    rcs.canonize;
    assert(rcs.is_leaf);
}

unittest
{
    auto s = DefenseState8(rectangle8(5, 4) & ~(Board8(0, 0) | Board8(1, 0) | Board8(1, 2) | Board8(2, 2) | Board8(3, 2) | Board8(3, 1)));
    s.opponent = (rectangle8(5, 4) & ~rectangle8(3, 3).east) & s.playing_area;
    s.opponent_target = s.opponent;
    auto old_target_size = s.opponent_target.popcount;
    s.reduce;
    assert(old_target_size == s.opponent_target.popcount);

    s.opponent_target = Board8();
    s.opponent_immortal = s.opponent;
    s.reduce;
    assert(s.opponent_immortal.popcount == 2);
}

unittest
{
    auto s = DefenseState8(Board8(0, 0));
    s.opponent = Board8(0, 0);
    s.opponent_target = s.opponent;
    s.opponent_outside_liberties = 1;

    foreach (c ;s.children){
        assert(c.passes > 0 || !c.player);
    }
}

unittest
{
    auto s = DefenseState8(Board8(0, 0) | Board8(2, 0));
    s.player = Board8(0, 0);
    s.player_immortal = s.player;
    assert(s.reduce == 1);
    assert(!s.player_immortal);

    s.playing_area = Board8(0, 0) | Board8(2, 0);
    s.player = Board8(0, 0);
    s.player_target = s.player;
    s.player_outside_liberties = 1;
    assert(s.reduce == 0);
    assert(s.player_target);
}