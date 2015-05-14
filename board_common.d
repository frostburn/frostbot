module board_common;


enum Transformation {none, rotate, flip, rotate_thrice, mirror_v_rotate, mirror_h, rotate_mirror_v, mirror_v};


T rectangle(T)(int width, int height){
    T result;
    for (int y = 0; y < height; y++){
        for (int x = 0; x < width; x++){
            result |= T(x, y);
        }
    }
    return result;
}
