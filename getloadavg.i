// SWIG wrapper for getloadavg()
/*
swig -tcl8 getloadavg.i
gcc -fpic -c getloadavg_wrap.c -I /usr/include/tcl
gcc -shared getloadavg_wrap.o -o getloadavg.so
tclsh
load ./getloadavg.so
loadavg_1m
loadavg_5m
loadavg_15m
exit
*/

%module getloadavg
%{
#include <stdlib.h>
%}

//int getloadavg(double loadavg[], int nelem);

// Hmm, rather than trying to map C array output arguments to Tcl, let's just write a wrapper C function (or three):

%inline %{

double loadavg_1m() {
	double* result;
	getloadavg(result, 1);
	return *result;
}

double loadavg_5m() {
	double result[2];
	getloadavg(result, 2);
	return result[1];
}

double loadavg_15m() {
	double result[3];
	getloadavg(result, 3);
	return result[2];
}

%}
