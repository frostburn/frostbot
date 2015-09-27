module linalg;

pragma(lib, "blas");
pragma(lib, "lapack");

extern(C) {
    alias float f_float;
    alias double f_double;
    alias int f_int;
}

// The C interface from the SciD library:
extern (C) void dgemv_(char *trans, f_int *m, f_int *n, f_double *alpha, f_double *A, f_int *lda, f_double *x, f_int *incx, f_double *beta, f_double *y, f_int *incy, f_int trans_len);
extern (C) void sgemv_(char *trans, f_int *m, f_int *n, f_float *alpha, f_float *A, f_int *lda, f_float *x, f_int *incx, f_float *beta, f_float *y, f_int *incy, f_int trans_len);

// The D interface is a D-ified call which calls the C interface sgemv_ or dgemv_
void gemv(char trans, f_int m, f_int n, f_float alpha, f_float *A, f_int lda,
f_float *x, f_int incx, f_float beta, f_float *y, f_int incy) {
    sgemv_(&trans, &m, &n, &alpha, A, &lda, x, &incx, &beta, y, &incy, 1);
}

void gemv(char trans, f_int m, f_int n, f_double alpha, f_double *A, f_int lda,
f_double *x, f_int incx, f_double beta, f_double *y, f_int incy) {
    dgemv_(&trans, &m, &n, &alpha, A, &lda, x, &incx, &beta, y, &incy, 1);
}


T[] dot(T)(in T[] vec, in T[] mat)
{
    size_t n = vec.length;
    size_t m = mat.length / vec.length;
    T[] result;
    result.length = m;
    result[] = 0;
    foreach (i; 0..m){
        foreach (j; 0..n){
            result[i] += vec[j] * mat[i + j * m];
        }
    }
    return result;
}
