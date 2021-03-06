
// compile with: nvcc -arch sm_60 -o reduction reduction.cu
// run: ./reduction

#include <stdio.h>
#include <stdlib.h>
#include "cuda.h"

// use this later to define number of threads in thread block
#define BSIZE 256

__global__ void partialReduction(int N, 
				 float *c_a,
				 float *c_result){

  // shared memory array
  __shared__ float s_a[BSIZE];

  // find thread number in thread-block
  int t = threadIdx.x;
  
  // find block number
  int b = blockIdx.x;

  // choose an array index for this thread to read
  int n = t + b*blockDim.x;

  // check is this index in bounds
  float a = 0;
  if(n<N)
    a = c_a[n];
  
  // store the entry in shared memory
  s_a[t] = a;

  // block until all threads have written to the shared memory
  __syncthreads();
  if(t<BSIZE/2) s_a[t] = s_a[t] + s_a[t+(BSIZE/2)];

  __syncthreads();
  if(t<BSIZE/4) s_a[t] = s_a[t] + s_a[t+(BSIZE/4)];

  __syncthreads();
  if(t<BSIZE/8) s_a[t] = s_a[t] + s_a[t+(BSIZE/8)];

  __syncthreads();
  if(t<BSIZE/16) s_a[t] = s_a[t] + s_a[t+(BSIZE/16)];

  __syncthreads();
  if(t<BSIZE/32) s_a[t] = s_a[t] + s_a[t+(BSIZE/32)];

  __syncthreads();
  if(t<BSIZE/64) s_a[t] = s_a[t] + s_a[t+(BSIZE/64)];

  __syncthreads();
  if(t<BSIZE/128) s_a[t] = s_a[t] + s_a[t+(BSIZE/128)];

  __syncthreads();
  if(t<BSIZE/256) s_a[t] = s_a[t] + s_a[t+(BSIZE/256)];

  if(t==0)
    c_result[b] = s_a[0];
}


int main(int argc, char **argv){

  int N = 10240;

  // host array
  float *h_a = (float*) malloc(N*sizeof(float));
  float *h_result = (float*) malloc(N*sizeof(float));

  int n;
  for(n=0;n<N;++n){
    h_a[n] = 1;
  }

  // allocate device array
  float *c_a, *c_result;

  cudaMalloc(&c_a, N*sizeof(float));
  cudaMalloc(&c_result, N*sizeof(float));

  // copy data from host to device
  cudaMemcpy(c_a, h_a, N*sizeof(float), cudaMemcpyHostToDevice);

  // choose number of threads in thread-block
  dim3 B(BSIZE,1,1);

  // choose number of thread-blocks
  int Nblocks = (N+BSIZE-1)/BSIZE;
  int Nblocks2 = (Nblocks+BSIZE-1)/BSIZE;
  dim3 G(Nblocks,1,1);
  dim3 G2(Nblocks2,1,1);

  printf("Nblocks = %d, Nblocks2 = %d\n", Nblocks, Nblocks2);

  // launch reduction kernel
  partialReduction <<< G, B >>> (N, c_a, c_result);

  partialReduction <<< G2, B >>> (Nblocks, c_result, c_a);

  // copy result back
  cudaMemcpy(h_result, c_result, 
	     Nblocks*sizeof(float), cudaMemcpyDeviceToHost);

  cudaMemcpy(h_result, c_a,
	     Nblocks2*sizeof(float), cudaMemcpyDeviceToHost);

  // print out partial sums
  for(n=0;n<Nblocks2;++n)
    printf("%f\n", h_result[n]);

  return 0;
}
