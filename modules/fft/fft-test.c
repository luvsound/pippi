/* 
 * FFT and convolution test (C)
 * 
 * Copyright (c) 2017 Project Nayuki. (MIT License)
 * https://www.nayuki.io/page/free-small-fft-in-multiple-languages
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 * - The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 * - The Software is provided "as is", without warranty of any kind, express or
 *   implied, including but not limited to the warranties of merchantability,
 *   fitness for a particular purpose and noninfringement. In no event shall the
 *   authors or copyright holders be liable for any claim, damages or other
 *   liability, whether in an action of contract, tort or otherwise, arising from,
 *   out of or in connection with the Software or the use or other dealings in the
 *   Software.
 */

#include <math.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "fft.h"


// Private function prototypes
static void test_fft(int n);
static void test_convolution(int n);
static void naive_dft(const double *inreal, const double *inimag,
	double *outreal, double *outimag, bool inverse, int n);
static void naive_convolve(const double *xreal, const double *ximag,
	const double *yreal, const double *yimag,
	double *outreal, double *outimag, int n);
static double log10_rms_err(const double *xreal, const double *ximag,
	const double *yreal, const double *yimag, int n);
static double *random_reals(int n);
static void *memdup(const void *src, size_t n);

static double max_log_error = -INFINITY;


/*---- Main and test functions ----*/

int main(void) {
	srand(time(NULL));
	
	// Test power-of-2 size FFTs
	for (int i = 0; i <= 12; i++)
		test_fft(1 << i);
	
	// Test small size FFTs
	for (int i = 0; i < 30; i++)
		test_fft(i);
	
	// Test diverse size FFTs
	for (int i = 0, prev = 0; i <= 100; i++) {
		int n = (int)lround(pow(1500, i / 100.0));
		if (n > prev) {
			test_fft(n);
			prev = n;
		}
	}
	
	// Test power-of-2 size convolutions
	for (int i = 0; i <= 12; i++)
		test_convolution(1 << i);
	
	// Test diverse size convolutions
	for (int i = 0, prev = 0; i <= 100; i++) {
		int n = (int)lround(pow(1500, i / 100.0));
		if (n > prev) {
			test_convolution(n);
			prev = n;
		}
	}
	
	printf("\n");
	printf("Max log err = %.1f\n", max_log_error);
	printf("Test %s\n", max_log_error < -10 ? "passed" : "failed");
	return EXIT_SUCCESS;
}


static void test_fft(int n) {
	double *inputreal = random_reals(n);
	double *inputimag = random_reals(n);
	
	double *refoutreal = malloc(n * sizeof(double));
	double *refoutimag = malloc(n * sizeof(double));
	naive_dft(inputreal, inputimag, refoutreal, refoutimag, false, n);
	
	double *actualoutreal = memdup(inputreal, n * sizeof(double));
	double *actualoutimag = memdup(inputimag, n * sizeof(double));
	Fft_transform(actualoutreal, actualoutimag, n);
	
	printf("fftsize=%4d  logerr=%5.1f\n", n,
		log10_rms_err(refoutreal, refoutimag, actualoutreal, actualoutimag, n));
	
	free(inputreal);
	free(inputimag);
	free(refoutreal);
	free(refoutimag);
	free(actualoutreal);
	free(actualoutimag);
}


static void test_convolution(int n) {
	double *input0real = random_reals(n);
	double *input0imag = random_reals(n);
	double *input1real = random_reals(n);
	double *input1imag = random_reals(n);
	
	double *refoutreal = malloc(n * sizeof(double));
	double *refoutimag = malloc(n * sizeof(double));
	naive_convolve(input0real, input0imag, input1real, input1imag, refoutreal, refoutimag, n);
	
	double *actualoutreal = malloc(n * sizeof(double));
	double *actualoutimag = malloc(n * sizeof(double));
	Fft_convolveComplex(input0real, input0imag, input1real, input1imag, actualoutreal, actualoutimag, n);
	
	printf("convsize=%4d  logerr=%5.1f\n", n,
		log10_rms_err(refoutreal, refoutimag, actualoutreal, actualoutimag, n));
	
	free(input0real);
	free(input0imag);
	free(input1real);
	free(input1imag);
	free(refoutreal);
	free(refoutimag);
	free(actualoutreal);
	free(actualoutimag);
}


/*---- Naive reference computation functions ----*/

static void naive_dft(const double *inreal, const double *inimag,
		double *outreal, double *outimag, bool inverse, int n) {
	
	double coef = (inverse ? 2 : -2) * M_PI;
	for (int k = 0; k < n; k++) {  // For each output element
		double sumreal = 0;
		double sumimag = 0;
		for (int t = 0; t < n; t++) {  // For each input element
			double angle = coef * ((long long)t * k % n) / n;
			sumreal += inreal[t] * cos(angle) - inimag[t] * sin(angle);
			sumimag += inreal[t] * sin(angle) + inimag[t] * cos(angle);
		}
		outreal[k] = sumreal;
		outimag[k] = sumimag;
	}
}


static void naive_convolve(const double *xreal, const double *ximag,
		const double *yreal, const double *yimag,
		double *outreal, double *outimag, int n) {
	
	for (int i = 0; i < n; i++) {
		outreal[i] = 0;
		outimag[i] = 0;
	}
	for (int i = 0; i < n; i++) {
		for (int j = 0; j < n; j++) {
			int k = (i + j) % n;
			outreal[k] += xreal[i] * yreal[j] - ximag[i] * yimag[j];
			outimag[k] += xreal[i] * yimag[j] + ximag[i] * yreal[j];
		}
	}
}


/*---- Utility functions ----*/

static double log10_rms_err(const double *xreal, const double *ximag,
		const double *yreal, const double *yimag, int n) {
	
	double err = pow(10, -99 * 2);
	for (int i = 0; i < n; i++) {
		double real = xreal[i] - yreal[i];
		double imag = ximag[i] - yimag[i];
		err += real * real + imag * imag;
	}
	
	err /= n > 0 ? n : 1;
	err = sqrt(err);  // Now this is a root mean square (RMS) error
	err = log10(err);
	if (err > max_log_error)
		max_log_error = err;
	return err;
}


static double *random_reals(int n) {
	double *result = malloc(n * sizeof(double));
	for (int i = 0; i < n; i++)
		result[i] = (rand() / (RAND_MAX + 1.0)) * 2 - 1;
	return result;
}


static void *memdup(const void *src, size_t n) {
	void *dest = malloc(n);
	if (dest != NULL)
		memcpy(dest, src, n);
	return dest;
}
