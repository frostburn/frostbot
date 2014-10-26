module ann;

import std.stdio;
import std.string;
import std.format;
import std.random;
import std.math;

import fast_math;
import board8;
import defense_state;


class Neuron
{
    float activation;
    Neuron[] inputs;
    float[] weights;

    invariant
    {
        assert(inputs.length + 1 == weights.length);
    }

    this()
    {
        weights ~= 0;
    }

    this(Neuron[] inputs, float[] weights){
        this.inputs = inputs.dup;
        this.weights = weights.dup;
    }

    void activate(){
        float sum = weights[0];
        foreach (index, input; inputs){
            float weight = weights[index + 1];
            sum += weight * input.activation;
        }
        //if (symmetric){
        //    activation = fast_erf(sum);
        //}
        //else{
            activation = 0.5 * (1.0 + fast_erf(sum));
        //}
    }

    void set_bias(float value)
    {
        weights[0] = value;
    }

    void add_input(ref Neuron input, float weight){
        inputs ~= input;
        weights ~= weight;
    }

    override string toString()
    {
        return format("N:%s", activation);
    }
}


struct Layer
{
    Neuron[] neurons;

    void activate(){
        foreach (neuron; neurons){
            neuron.activate;
        }
    }

    Layer copy(){
        auto duplicate = Layer();
        foreach (neuron; neurons){
            if (neuron is null){
                duplicate.neurons ~= null;
            }
            else{
                duplicate.neurons ~= new Neuron();
            }
        }
        return duplicate;
    }
}

struct InputLayer(T)
{
    bool symmetric;
    size_t width;
    size_t height;
    Layer layer;

    this(T playing_area)
    {
        width = playing_area.horizontal_extent;
        height = playing_area.vertical_extent;
        foreach (y; 0..height){
            foreach(x; 0..width){
                T p = T(x, y);
                if (p & playing_area){
                    layer.neurons ~= new Neuron();
                    layer.neurons ~= new Neuron();
                }
                else{
                    layer.neurons ~= null;
                    layer.neurons ~= null;
                }
            }
        }
    }

    void get_input(T player, T opponent)
    {
        foreach (y; 0..height){
            foreach(x; 0..width){
                size_t index = 2 * (x + y * width);
                T p = T(x, y);
                if (p & player){
                    layer.neurons[index].activation = 1;
                    layer.neurons[index + 1].activation = 0;
                }
                else if (p & opponent){
                    layer.neurons[index].activation = 0;
                    layer.neurons[index + 1].activation = 1;
                }
                else if (layer.neurons[index] !is null){
                    layer.neurons[index].activation = 0;
                    layer.neurons[index + 1].activation = 0;
                }
            }
        }
    }

    InputLayer!T copy()
    {
        auto duplicate = InputLayer!T();
        duplicate.width = width;
        duplicate.height = height;
        duplicate.layer = layer.copy;

        return duplicate;
    }
}

struct Network(T)
{
    InputLayer!T input_layer;
    Layer[] layers;
    this(T playing_area, size_t number_of_hidden_layers=0)
    {
        input_layer = InputLayer!T(playing_area);
        foreach (i; 0..number_of_hidden_layers + 1){
            layers ~= input_layer.layer.copy;
        }
        connect_layers;
    }

    void get_neighbours(
        size_t layer_index, size_t neuron_index,
        out Neuron player_north, out Neuron player_east, out Neuron player_west, out Neuron player_south, out Neuron player_middle,
        out Neuron opponent_north, out Neuron opponent_east, out Neuron opponent_west, out Neuron opponent_south, out Neuron opponent_middle,
        out bool is_central
    )
    {
        size_t width = input_layer.width;
        size_t height = input_layer.height;
        size_t y = (neuron_index / 2) / width;
        size_t x = (neuron_index /2 ) % width;
        bool is_x_central = x == width / 2;
        if (width % 2 == 0){
            is_x_central |= x == width / 2 - 1;
        }
        bool is_y_central = y == height / 2;
        if (height % 2 == 0){
            is_y_central |= y == height / 2 - 1;
        }
        is_central = is_y_central && is_x_central;
        Layer layer;
        int s;
        if (neuron_index % 2 == 0){
            s = 1;
        }
        else {
            s = -1;
        }

        if (layer_index == 0){
            layer = input_layer.layer;
        }
        else{
            layer = layers[layer_index - 1];
        }

        if (y == 0){
            player_north = null;
            opponent_north = null;
        }
        else{
            player_north = layer.neurons[neuron_index - 2 * width];
            opponent_north = layer.neurons[neuron_index - 2 * width + s];
        }
        if (x == width - 1){
            player_east = null;
            opponent_east = null;
        }
        else{
            player_east = layer.neurons[neuron_index + 2];
            opponent_east = layer.neurons[neuron_index + 2 + s];
        }
        if (x == 0){
            player_west = null;
            opponent_west = null;
        }
        else{
            player_west = layer.neurons[neuron_index - 2];
            opponent_west = layer.neurons[neuron_index - 2 + s];
        }
        if (y == height - 1){
            player_south = null;
            opponent_south = null;
        }
        else{
            player_south = layer.neurons[neuron_index + 2 * width];
            opponent_south = layer.neurons[neuron_index + 2 * width + s];
        }
        player_middle = layer.neurons[neuron_index];
        opponent_middle = layer.neurons[neuron_index + s];
    }

    void connect_layers()
    {
        foreach (layer_index; 0..layers.length){
            auto layer = layers[layer_index];
            foreach (neuron_index, neuron; layer.neurons){
                Neuron player_north, player_east, player_west, player_south, player_middle;
                Neuron opponent_north, opponent_east, opponent_west, opponent_south, opponent_middle;
                bool is_central;
                get_neighbours(
                    layer_index, neuron_index,
                    player_north, player_east, player_west, player_south, player_middle,
                    opponent_north, opponent_east, opponent_west, opponent_south, opponent_middle,
                    is_central
                );
                if (player_middle !is null){
                    if (is_central){
                        neuron.add_input(player_middle, 1);
                    }
                    else{
                        neuron.add_input(player_middle, 0.5);
                    }
                }
                foreach (ref neighbour; [player_north, player_east, player_west, player_south, opponent_north, opponent_east, opponent_west, opponent_south, opponent_middle]){
                    if (neighbour !is null){
                        neuron.add_input(neighbour, 0);
                    }
                }
            }
        }
    }

    void activate(T player, T opponent, float noise_level=0)
    {
        input_layer.get_input(player, opponent);
        if (noise_level != 0){
            foreach (ref neuron; input_layer.layer.neurons){
                neuron.activation += 2 * uniform01 * noise_level - noise_level;
            }
        }
        foreach (layer; layers){
            layer.activate;
        }
    }

    float get_sum()
    {
        float sum = 0.0;
        foreach (index, ref neuron; layers[$ - 1].neurons){
            if (neuron !is null){
                if (index & 1){
                    sum -= neuron.activation;
                }
                else{
                    sum += neuron.activation;
                }
            }
        }
        return sum;
    }

    Network!T copy()
    {
        auto duplicate = Network!T();
        duplicate.input_layer = input_layer.copy();
        foreach (ref layer; layers){
            duplicate.layers ~= layer.copy;
        }
        duplicate.connect_layers;
        foreach (layer_index, layer; layers){
            foreach (neuron_index, neuron; layer.neurons){
                foreach (weight_index, weight; neuron.weights){
                    duplicate.layers[layer_index].neurons[neuron_index].weights[weight_index] = weight;
                }
            }
        }

        /*
        foreach (layer_index, ref layer; duplicate.layers){
            Layer my_layer;
            Layer duplicate_layer;
            if (layer_index == 0){
                my_layer = input_layer.layer;
                duplicate_layer = duplicate.input_layer.layer;
            }
            else{
                my_layer = layers[layer_index - 1];
                duplicate_layer = duplicate.layers[layer_index - 1];
            }
            foreach (neuron_index, ref neuron; layer.neurons){
                if (neuron !is null){
                    foreach (input_index, ref input_neuron; layers[layer_index].neurons[neuron_index].inputs){
                        float weight = layers[layer_index].neurons[neuron_index].weights[input_index];
                        foreach (candidate_index, ref candidate_neuron; my_layer.neurons){
                            if (candidate_neuron is input_neuron){
                                neuron.add_input(duplicate_layer.neurons[candidate_index], weight);
                            }
                        }
                    }
                }
            }
        }
        */

        return duplicate;
    }

    void mutate(float amount)
    {
        auto layer = layers[uniform(0, layers.length)];
        Neuron neuron = null;
        while(neuron is null){
            neuron = layer.neurons[uniform(0, layer.neurons.length)];
        }
        neuron.weights[uniform(0, neuron.weights.length)] += 2 * uniform01 * amount - amount;
    }

    string toString()
    {
        // TODO: remove extra ","s.
        string r;
        r ~= format("width=%s;height=%s;layers=%s;", input_layer.width, input_layer.height, layers.length);
        foreach (neuron; input_layer.layer.neurons){
            if (neuron is null){
                r ~= "n,";
            }
            else{
                r ~= "N,";
            }
        }
        r = r[0..$-1] ~ ";";
        foreach (layer; layers){
            foreach (neuron; layer.neurons){
                foreach (weight; neuron.weights){
                    r ~= format("%s,", weight);
                }
            }
        }
        return r[0..$-1];
    }

    static Network!T from_string(string s)
    {
        auto tokens = split(s, ";");
        size_t width, height, num_layers;
        formattedRead(tokens[0],"width=%s", &width);
        formattedRead(tokens[1],"height=%s", &height);
        formattedRead(tokens[2],"layers=%s", &num_layers);

        auto network = Network!T();

        with (network){
            input_layer.width = width;
            input_layer.height = height;

            foreach (sub_token; split(tokens[3], ",")){
                if (sub_token == "N"){
                    input_layer.layer.neurons ~= new Neuron();
                }
                else{
                    input_layer.layer.neurons ~= null;
                }
            }
            foreach (i; 0..num_layers){
                layers ~= input_layer.layer.copy;
            }
            connect_layers;

            size_t layer_index = 0;
            size_t neuron_index = 0;
            size_t weight_index = 0;
            foreach (sub_token; split(tokens[4], ",")){
                float weight;
                formattedRead(sub_token,"%s", &weight);
                layers[layer_index].neurons[neuron_index].weights[weight_index] = weight;

                weight_index++;
                if (weight_index == layers[layer_index].neurons[neuron_index].weights.length){
                    weight_index = 0;
                    neuron_index++;
                    if (neuron_index == layers[layer_index].neurons.length){
                        neuron_index = 0;
                        layer_index++;
                    }
                }
            }
        }

        return network;
    }

    static from_file(string file_name){
        File file = File(file_name, "r");
        auto line = file.readln;
        return Network!T.from_string(line);
    }

    float get_score(S)(S state, float noise_level=0)
    {
        float score = 0;

        activate(state.opponent, state.player, noise_level);
        score += get_sum;
        state.mirror_v;
        state.snap;
        activate(state.opponent, state.player, noise_level);
        score += get_sum;
        state.mirror_h;
        state.snap;
        activate(state.opponent, state.player, noise_level);
        score += get_sum;
        state.mirror_v;
        state.snap;
        activate(state.opponent, state.player, noise_level);
        score += get_sum;

        return score;
    }

}

alias Network8 = Network!Board8;

float fight(T)(DefenseState!T state, Network!T network0, Network!T network1, float noise_level=0, int depth=1000, bool print=false)
{
    if (print){
        writeln(state);
    }
    if (state.is_leaf){
        return state.liberty_score;
    }
    else if (depth <= 0){
        return 0;
    }
    DefenseState!T best_child;
    float best_score = -float.infinity;
    foreach (child; state.children){
        child.analyze_unconditional;
        float score = network0.get_score!(DefenseState!T)(state, noise_level);
        if (score > best_score){
            best_child = child;
            best_score = score;
        }
    }
    //if (print){
    //    best_child.mirror_h;
    //    best_child.snap;
    //}
    return fight!T(best_child, network1, network0, noise_level, depth - 1, print);
}

void tournament(T)(
    T playing_area, Network!T network,
    size_t pool_size=8, size_t iterations=1000, float noise_level=0, int depth=1000,
    float mutation_level=0.1, int mutation_count=3
)
{
    Network!T[] networks;
    Network!T best_network;

    foreach (i; 0..pool_size){
        networks ~= network.copy;
    }

    auto state = DefenseState!T(playing_area);

    foreach(iteration; 0..iterations){
        float[] scores;
        foreach (ref network0; networks){
            scores ~= 0;
        }
        foreach (index0, ref network0; networks){
            foreach (index1; index0 + 1..networks.length){
                auto network1 = networks[index1];
                float score0 = fight(state, network0, network1, noise_level, depth);
                float score1 = fight(state, network1, network0, noise_level, depth);
                scores[index0] += score0 - score1;
                scores[index1] += score1 - score0;
            }
            scores[index0] += uniform01 * 0.01;
        }

        float best_score = -float.infinity;
        float worst_score = float.infinity;
        size_t worst_index;
        Network!T new_network;
        foreach (index, score; scores){
            if (score < worst_score){
                worst_score = score;
                worst_index = index;
            }
            if (score > best_score){
                best_score = score;
                best_network = networks[index];
                new_network = networks[index].copy;
            }
        }

        foreach (ref score; scores){
            score = floor(score);
        }
        writeln(scores);

        foreach(i; 0..mutation_count){
            new_network.mutate(mutation_level);
        }
        networks[worst_index] = new_network;
    }
    writeln(best_network);
    fight(state, best_network, best_network, noise_level, 20, true);
}
