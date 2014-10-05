import std.stdio;
import std.string;

// TODO: Move to utils
int popcount(ulong b)
{
     b = (b & 0x5555555555555555UL) + (b >> 1 & 0x5555555555555555UL);
     b = (b & 0x3333333333333333UL) + (b >> 2 & 0x3333333333333333UL);
     b = b + (b >> 4) & 0x0F0F0F0F0F0F0F0FUL;
     b = b + (b >> 8);
     b = b + (b >> 16);
     b = b + (b >> 32) & 0x0000007FUL;

     return cast(int)b;
}

struct Board8
{
    enum WIDTH = 8;
    enum HEIGHT = 7;
    enum H_SHIFT = 1;
    enum V_SHIFT = 9;
    enum EMPTY = 0UL;
    enum FULL = 4602661192559623935UL;
    enum OUTSIDE = 13844082881149927680UL;

    static immutable Board8[28] FORAGE = [
        Board8(513UL),
        Board8(1026UL),
        Board8(2052UL),
        Board8(4104UL),
        Board8(8208UL),
        Board8(16416UL),
        Board8(32832UL),
        Board8(65664UL),
        Board8(134479872UL),
        Board8(268959744UL),
        Board8(537919488UL),
        Board8(1075838976UL),
        Board8(2151677952UL),
        Board8(4303355904UL),
        Board8(8606711808UL),
        Board8(17213423616UL),
        Board8(35253091565568UL),
        Board8(70506183131136UL),
        Board8(141012366262272UL),
        Board8(282024732524544UL),
        Board8(564049465049088UL),
        Board8(1128098930098176UL),
        Board8(2256197860196352UL),
        Board8(4512395720392704UL),
        Board8(54043195528445952UL),
        Board8(216172782113783808UL),
        Board8(864691128455135232UL),
        Board8(3458764513820540928UL),
    ];

    ulong bits = EMPTY;

    bool valid() const
    {
        return !(bits & OUTSIDE);
    }

    //Invariant disabled because optimizations depend on creating invalid temporary objects.
    //invariant()
    //{
    //    assert(valid);
    //}

    this(in ulong bits)
    {
        this.bits = bits;
    }

    this(in int x, in int y)
    in
    {
        assert((0 <= x) && (x < WIDTH) && (0 <= y) && (y < HEIGHT));
    }
    out
    {
        assert(valid);
    }
    body
    {
        bits = (1UL << (x * H_SHIFT)) << (y * V_SHIFT);
    }

    Board8 opUnary(string op)() const
    {
        mixin("return Board8(" ~ op ~ "bits);");
    }

    Board8 opBinary(string op)(in Board8 rhs) const
    {
        mixin("return Board8(bits " ~ op ~ " rhs.bits);");
    }

    Board8 opBinary(string op)(in int rhs) const
    {
        mixin("return Board8(bits " ~ op ~ " rhs);");
    }

    Board8 opBinary(string op)(in ulong rhs) const
    {
        mixin("return Board8(bits " ~ op ~ " rhs);");
    }

    ref Board8 opOpAssign(string op)(in Board8 rhs)
    {
        mixin ("bits " ~ op ~ "= rhs.bits;");
        return this;
    }

    bool opEquals(in Board8 rhs) const
    {
        return bits == rhs.bits;
    }

    hash_t toHash() const nothrow @safe
    {
        return typeid(bits).getHash(&bits);
    }

    Board8 liberties(in Board8 playing_area) const
    {
        return (
            (this << H_SHIFT) |
            (this >> H_SHIFT) |
            (this << V_SHIFT) |
            (this >> V_SHIFT)
        ) & (~this) & playing_area;
    }

    Board8 east(in int n=1) const
    {
        return (this << (H_SHIFT * n)) & FULL;
    }

    Board8 west(in int n=1) const
    {
        return (this >> (H_SHIFT * n)) & FULL;
    }

    Board8 south(in int n=1) const
    {
        return (this << (V_SHIFT* n)) & FULL;
    }

    Board8 north(in int n=1) const
    {
        return (this >> (V_SHIFT * n)) & FULL;
    }

    /**
     * Floods (expands) the board into target board along vertical and horizontal lines.
     */
    ref Board8 flood_into(in Board8 target)
    in
    {
        assert(target.valid);
    }
    out
    {
        assert(valid);
    }
    body
    {
        Board8 temp;

        this &= target;
        if (!this){
            return this;
        }

        // The "+" operation can be thought as an infinite inverting horizontal flood with a garbage bit at each end.
        // Here we invert it back and clear the garbage bits by "&":ing with the target.
        this |= (~(this + target)) & target;
        do{
            temp = this;
            this |= (
                (this >> H_SHIFT) |
                (this << V_SHIFT) |
                (this >> V_SHIFT)
            ) & target;
            this |= (~(this + target)) & target;
        } while(this != temp);

        return this;
    }

    void clear()
    {
        bits = EMPTY;
    }

    void fill(){
        bits = FULL;
    }

    string toString()
    {
        string r;
        for (int y = 0; y < HEIGHT; y++){
            for (int x = 0; x < WIDTH; x++){
                if (this & Board8(x, y)){
                    r ~= "@ ";
                }
                else{
                    r ~= ". ";
                }
            }
            if (y != HEIGHT - 1){
                r ~= "\n";
            }
        }
        return r;
    }

    string raw_string()
    {
        string r;
        for (int y = 0; y < HEIGHT + 1; y++){
            for (int x = 0; x < WIDTH + 1; x++){
                if (bits & ((1UL << (x * H_SHIFT)) << (y * V_SHIFT))){
                    r ~= "@ ";
                }
                else{
                    r ~= ". ";
                }
                if (y == HEIGHT){
                    return r;
                }
            }
            r ~= "\n";
        }
        assert(false);
    }

    string repr()
    {
        return format("Board8(%sUL)", bits);
    }

    @property bool toBool() const
    {
        return cast(bool)bits;
    }

    alias toBool this;
}

T rectangle(T)(int width, int height){
    T result;
    for (int y = 0; y < height; y++){
        for (int x = 0; x < width; x++){
            result |= T(x, y);
        }
    }
    return result;
}

immutable Board8 full8 = Board8(Board8.FULL);
immutable Board8 empty8 = Board8(Board8.EMPTY);

int popcount(Board8 b)
{
    return popcount(b.bits);
}


void print_forage_pattern()
{
    Board8 forage[];
    for (int y = 0; y < Board8.HEIGHT - 1; y += 2){
        for (int x = 0; x < Board8.WIDTH; x++){
            Board8 block = Board8(x, y);
            block |= Board8(x, y + 1);
            forage ~= block;
        }
    }
    int y = Board8.HEIGHT - 1;
    for (int x = 0; x < Board8.WIDTH; x += 2){
        Board8 block = Board8(x, y);
        block |= Board8(x + 1, y);
        forage ~= block;
    }
    writeln("[");
    foreach (block; forage){
        writeln("    " ~ block.repr() ~ ",");
    }
    writeln("];");
}

unittest
{
    Board8 b0 = Board8(0, 1);
    Board8 b1 = Board8(0, 0);
    b1 |= b0;
    b1 |= Board8(1, 1);
    b1 |= Board8(2, 1);
    b1 |= Board8(2, 2);
    b1 |= Board8(3, 2);
    b1 |= Board8(3, 3);
    b1 |= Board8(3, 4);
    b1 |= Board8(2, 4);

    Board8 b2 = b1;
    b2 |= Board8(4, 5);
    b2 |= Board8(7, 1);

    b0.flood_into(b2);

    assert(b0 == b1);
}

unittest
{
    Board8 b = Board8(Board8.FULL);
    assert(b.popcount() == Board8.WIDTH * Board8.HEIGHT);
}

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

class GameState(T)
{
    State!T state;
    float low_value = -float.infinity;
    float high_value = float.infinity;
    bool is_leaf;
    GameState!T[] children;
    bool complete;

    private
    {
        T[] moves;
        GameState!T[][State!T] hooks;
        bool[State!T] dependencies;
    }

    this(T playing_area)
    {
        state = State!T(playing_area);
        calculate_available_moves();
    }

    this(State!T state, T[] moves=null)
    {
        this.state = state;
        if (state.passes >= 2){
            is_leaf = true;
            update_value;
        }
        else{
            if (moves){
                this.moves = moves;
            }
            else{
                calculate_available_moves();
            }
        }
    }

    invariant
    {
        assert(state.passes <= 2);

        if (is_leaf){
            assert(!hooks.length);
            assert(!dependencies.length);
        }
    }

    GameState!T copy(){
        return new GameState!T(state);
    }

    void calculate_available_moves()
    {
        for (int y = 0; y < T.HEIGHT; y++){
            for (int x = 0; x < T.WIDTH; x++){
                T move = T(x, y);
                if (move & state.playing_area){
                    moves ~= move;
                }
            }
        }
        moves ~= T();
    }

    void make_children(GameState!T[State!T] state_pool=null)
    {
        auto state_children = state.children(moves);
        children = [];
        // Collect novel states first.
        foreach(child_state; state_children){
            if (!(state_pool.length && child_state in state_pool)){
                children ~= new GameState!T(child_state, moves);
            }
        }
        foreach(child_state; state_children){
            if (state_pool.length && child_state in state_pool){
                children ~= state_pool[child_state];
            }
        }
    }

    void hook(GameState!T other, State!T key)
    {
        if (!(key in hooks)){
            hooks[key] = [];
        }
        hooks[key] ~= other;
        other.dependencies[key] = true;
    }

    void hook(GameState!T other)
    {
        hook(other, state);
    }

    void release_hooks(State!T key){
        debug(release_hooks) {
            writeln("Releasing hooks with key:");
            writeln(key);
        }
        if (key in hooks){
            foreach(hook; hooks[key].dup){
                hook.update_value;
                hook.dependencies.remove(key);
                //hooks[key].remove(hook);
                hook.release_hooks(key);
                if (!hook.dependencies.length){
                    hook.release_hooks;
                }
            }
            hooks.remove(key);
        }
    }

    void release_hooks(){
        release_hooks(state);
    }

    void update_value(){
        if (!is_leaf){
            float sign;
            if (state.black_to_play){
                sign = +1;
            }
            else{
                sign = -1;
            }
            low_value = -sign * float.infinity;
            high_value = -sign * float.infinity;
            foreach(child; children){
                if (child.low_value * sign > low_value * sign){
                    low_value = child.low_value;
                }
                if (child.high_value * sign > high_value * sign){
                    high_value = child.high_value;
                }
            }
        }
        else{
            low_value = high_value = state.liberty_score;
            complete = true;
        }
    }

    void calculate_minimax_value(bool[State!T] history=null, GameState!T[State!T] state_pool=null){
        debug(minimax) {
            writeln("Minimaxing:");
            writeln(state_pool.length);
            //writeln(this);
        }
        if (state_pool is null){
            GameState!T[State!T] empty;
            state_pool = empty;
        }
        if (!(state in state_pool)){
            state_pool[state] = this;
        }
        else if(state_pool[state].complete){
            assert(state_pool[state] == this);
            return;
        }

        if (is_leaf){
            return;
        }

        make_children(state_pool);

        if (history is null){
            history = [state : true];
        }
        else{
            history = history.dup;
            history[state] = true;
        }

        foreach (child; children){
            if (!child.is_leaf){
                if (child.state in history){
                    child.hook(this);
                }
                else{
                    child.calculate_minimax_value(history, state_pool);
                    foreach (dependency; child.dependencies.byKey){
                        if (dependency != state){
                            child.hook(this, dependency);
                        }
                    }
                }
            }
        }

        update_value;

        if (!dependencies.length){
            //release_hooks;
            complete = true;
            debug(complete){
                writeln("Complete!");
                writeln(this);
            }
        }
    }

    /*
    void calculate_self_minimax_value(bool[State!T] history=null, GameState!T[State!T] state_pool=null)
    {
        if (is_leaf){
            return;
        }

        make_children(state_pool);

        if (history is null){
            history = [state : true];
        }
        else{
            history = history.dup;
            history[state] = true;
        }

        foreach (child; children){
            if (!child.is_leaf){
                if (!(child.state in history)){
                    child.calculate_minimax_value(history, state_pool);
                    foreach (dependency; child.dependencies.byKey){
                        if (dependency != state){
                            child.hook(this, dependency);
                        }
                    }
                }
            }
        }

        update_value;
    }
    */

    override string toString()
    {
        return format(
            "%s\nlow_value=%s high_value=%s number of children=%s",
            state,
            low_value,
            high_value,
            children.length
        );
    }

    GameState!T[] principal_path(string type)(int max_depth=100)
    {
        if (max_depth <= 0){
            return [];
        }
        GameState!T[] result = [this];
        foreach(child; children){
            if (mixin("child." ~ type ~ "_value == " ~ type ~ "_value")){
                result ~= child.principal_path!type(max_depth - 1);
                break;
            }
        }
        return result;
    }
}

unittest
{
    auto gs = new GameState!Board8(rectangle!Board8(1, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == 0);
    assert(gs.high_value == 0);

    gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == -2);
    assert(gs.high_value == 2);

    gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.state.opponent = Board8(0, 0);
    gs.state.ko = Board8(1, 0);
    gs.calculate_minimax_value;
    assert(gs.low_value == -2);
    assert(gs.high_value == 2);

    gs = new GameState!Board8(rectangle!Board8(3, 1));
    gs.calculate_minimax_value;
    assert(gs.low_value == 3);
    assert(gs.high_value == 3);
}

/*
unittest
{
    auto gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.calculate_minimax_value;
    foreach (p; gs.principal_path!"high"){
        assert(!p.dependencies.length);
        auto c = p.copy;
        c.calculate_minimax_value;
        assert(c.low_value == p.low_value);
        assert(c.high_value == p.high_value);
    }
}
*/

/*
void main()
{
    auto gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.state.black_to_play = false;
    gs.state.opponent |= Board8(1, 0);
    gs.calculate_minimax_value;
    foreach (p; gs.principal_path!"low"){
        writeln(p);
        //writeln(p.dependencies);
        writeln;
    }
}
*/
/*
void main()
{
    offending_state = State!Board8(rectangle!Board8(2, 1));
    offending_state.opponent = Board8(0, 0);
    offending_state.ko = Board8(1, 0);
    offending_state.black_to_play = false;


    auto gs = new GameState!Board8(rectangle!Board8(2, 1));
    gs.calculate_minimax_value;
    foreach (p; gs.principal_path!"high"(5)){
        writeln(p);
        foreach (dependency, dummy; p.dependencies){
            writeln("-----------dependency-----------");
            writeln(dependency);
            assert(dependency == offending_state);
        }
        if (p.dependencies.length) writeln("*********");
        writeln;
    }
    //writeln(gs);
}
*/

void main()
{
    //auto gs = new GameState!Board8(rectangle!Board8(4, 1));
    auto gs = new GameState!Board8(rectangle!Board8(2, 2));
    gs.calculate_minimax_value;
    writeln(gs);
}