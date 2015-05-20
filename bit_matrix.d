module bit_matrix;

import std.stdio;

import utils;


struct BitMatrix{
    private
    {
        enum FIRST_ROW = 0xFFUL;
        enum FIRST_COLUMN = 0x101010101010101UL;
        ulong[] submatrices;
        size_t h_count;
        size_t v_count;
        size_t submatrix_count;
    }

    invariant
    {
        assert(submatrices.length == submatrix_count);
        assert(h_count * v_count == submatrix_count);
    }

    this(in size_t width, in size_t height)
    {
        if (width & 7){
            h_count = (width >> 3) + 1;
        }
        else{
            h_count = width >> 3;
        }
        if (height & 7){
            v_count = (height >> 3) + 1;
        }
        else{
            v_count = height >> 3;
        }

        submatrix_count = h_count * v_count;
        submatrices.length = submatrix_count;
    }

    bool has_key()
    {
        return submatrices.length == 1;
    }

    ulong key()
    {
        assert(has_key);
        return submatrices[0];
    }

    void from_key(ulong key)
    {
        assert(has_key);
        submatrices[0] = key;
    }

    void set(size_t i, size_t j)
    in
    {
        assert(i < 8 * h_count);
        assert(j < 8 * v_count);
    }
    body
    {
        size_t index_i, index_j;
        index_i = i >> 3;
        index_j = j >> 3;
        i &= 7;
        j &= 7;

        submatrices[index_i + index_j * h_count] |= 1UL << (i | (j << 3));
    }

    bool get(size_t i, size_t j)
    in
    {
        assert(i < 8 * h_count);
        assert(j < 8 * v_count);
    }
    body
    {
        size_t index_i, index_j;
        index_i = i >> 3;
        index_j = j >> 3;
        i &= 7;
        j &= 7;

        return ( submatrices[index_i + index_j * h_count] & (1UL << (i | (j << 3))) ) != 0UL;
    }

    bool row_nonzero(size_t j)
    in
    {
        assert(j < 8 * v_count);
    }
    body
    {
        size_t index_j_times_h_count = (j >> 3) * h_count;
        j &= 7;
        ulong mask = FIRST_ROW << (j << 3);
        for (size_t index_i = 0; index_i < h_count; index_i++){
            if (submatrices[index_i + index_j_times_h_count] & mask){
                return true;
            }
        }
        return false;
    }

    bool column_nonzero(size_t i)
    in
    {
        assert(i < 8 * h_count);
    }
    body
    {
        size_t index_i = i >> 3;
        i &= 7;
        ulong mask = FIRST_COLUMN << i;
        for (
            size_t index_j_times_h_count=0;
            index_j_times_h_count < submatrix_count;
            index_j_times_h_count += h_count
        ){
            if (submatrices[index_i + index_j_times_h_count] & mask){
                return true;
            }
        }
        return false;
    }

    uint row_popcount(size_t j)
    in
    {
        assert(j < 8 * v_count);
    }
    body
    {
        size_t index_j_times_h_count = (j >> 3) * h_count;
        uint sum = 0;
        j &= 7;
        ulong mask = FIRST_ROW << (j << 3);
        for(size_t index_i = 0; index_i < h_count; index_i++){
            sum += popcount(submatrices[index_i + index_j_times_h_count] & mask);
        }
        return sum;
    }

    // TODO: Tidy up the rest of the functions.

    uint column_popcount(size_t i)
    {
        size_t index_i, index_j_times_h_count;
        uint sum=0;
        ulong mask;
        index_i = i >> 3;
        i &= 7;
        mask = FIRST_COLUMN << i;
        for(index_j_times_h_count=0;index_j_times_h_count<submatrix_count;index_j_times_h_count+=h_count)
            sum += popcount( submatrices[index_i + index_j_times_h_count] & mask );
        return sum;
    }

    void clear_row(size_t j)
    {
        size_t index_i, index_j_times_h_count;
        ulong mask;
        index_j_times_h_count = (j >> 3)*h_count;
        j &= 7;
        mask = ~(FIRST_ROW << (j << 3));
        for(index_i=0;index_i<h_count;index_i++)
            submatrices[index_i + index_j_times_h_count] &= mask;
    }

    void clear_column(size_t i)
    {
        size_t index_i, index_j_times_h_count;
        ulong mask;
        index_i = i >> 3;
        i &= 7;
        mask = ~(FIRST_COLUMN << i);
        for(index_j_times_h_count=0;index_j_times_h_count<submatrix_count;index_j_times_h_count+=h_count)
            submatrices[index_i + index_j_times_h_count] &= mask;
    }

    bool clear_columns_by_row(size_t j)
    {
        size_t index_i, index_j_times_h_count, index_j2_times_h_count;
        ulong clearing_mask;
        bool something_cleared = false;
        index_j_times_h_count = (j >> 3)*h_count;
        j &= 7;
        j <<= 3;
        for(index_i=0;index_i<h_count;index_i++){
            clearing_mask = ( submatrices[index_i + index_j_times_h_count] >> j )&FIRST_ROW;
            clearing_mask |= clearing_mask << 8;
            clearing_mask |= clearing_mask << 16;
            clearing_mask |= clearing_mask << 32;
            for(index_j2_times_h_count=0;index_j2_times_h_count<submatrix_count;index_j2_times_h_count+=h_count){
                something_cleared = something_cleared || (clearing_mask & submatrices[index_i + index_j2_times_h_count]);
                submatrices[index_i + index_j2_times_h_count] &= ~clearing_mask;
            }
        }
        return something_cleared;
    }

    bool clear_rows_by_column(size_t i)
    {
        size_t index_i, index_j_times_h_count, index_i2;
        ulong clearing_mask;
        bool something_cleared = false;
        index_i = i >> 3;
        i &= 7;
        for(index_j_times_h_count=0;index_j_times_h_count<submatrix_count;index_j_times_h_count+=h_count){
            clearing_mask = ( submatrices[index_i + index_j_times_h_count]  >> i )&FIRST_COLUMN;
            clearing_mask |= clearing_mask << 1;
            clearing_mask |= clearing_mask << 2;
            clearing_mask |= clearing_mask << 4;
            for(index_i2=0;index_i2<h_count;index_i2++){
                something_cleared = something_cleared || (clearing_mask & submatrices[index_i2 + index_j_times_h_count]);
                submatrices[index_i2 + index_j_times_h_count] &= ~clearing_mask;
            }
        }
        return something_cleared;
    }

    string toString()
    {
        string r;
        for (size_t j = 0; j < v_count * 8; j++){
            for (size_t i = 0; i < h_count * 8; i++){
                if (get(i, j)){
                    r ~= "@ ";
                }
                else{
                    r ~= ". ";
                }
            }
            if (j != v_count * 8 - 1){
                r ~= "\n";
            }
        }
        return r;
    }
}

unittest
{
    BitMatrix bm = BitMatrix(17, 17);
    assert(bm.h_count == 3);
    assert(bm.v_count == 3);

    bm = BitMatrix(16, 16);
    assert(bm.h_count == 2);
    assert(bm.v_count == 2);

    bm.set(13, 15);
    assert(bm.get(13, 15));
    assert(bm.row_nonzero(15));
    assert(bm.column_nonzero(13));

    bm.set(13, 5);
    assert(bm.row_popcount(5) == 1);
    assert(bm.column_popcount(13) == 2);

    bm.set(2, 15);
    bm.set(9, 5);
    bm.set(7, 7);
    bm.clear_rows_by_column(13);
    assert(!bm.get(2, 15));
    assert(!bm.get(9, 5));
    assert(!bm.get(13, 15));
    assert(!bm.get(13, 5));
    assert(bm.get(7, 7));
}