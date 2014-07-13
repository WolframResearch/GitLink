/*************************************************************************
                        Mathematica source file

        Copyright 1986 through 2000 by Wolfram Research Inc.

This material contains trade secrets and may be registered with the
U.S. Copyright Office as an unpublished work, pursuant to Title 17,
U.S. Code, Section 408.  Unauthorized copying, adaptation, distribution
or display is prohibited.

$Id: WolframLibrary.h,v 1.62 2014/05/16 19:53:42 kkouptsov Exp $

*************************************************************************/

#ifndef WOLFRAMLIBRARY_H
#define WOLFRAMLIBRARY_H

#include "setjmp.h"

#define WolframLibraryVersion 3

#if !(defined(MATHEMATICA_KERNEL) || defined(MATHEMATICA_RUNTIME))

#include <stddef.h>

#define True	1
#define False	0

#ifdef MINT_32
#ifdef _WIN32
typedef __w64 int mint;
#else
typedef int mint;
#endif
#else
#ifdef _WIN64
typedef long long mint;
#else
typedef long mint;
#endif
#endif

typedef int mbool;

typedef double mreal;

typedef struct {mreal ri[2];} mcomplex;

#define mcreal(mc)	(((mc).ri)[0])
#define mcimag(mc)	(((mc).ri)[1])

typedef struct M_TENSOR_STRUCT* MTensor;

typedef struct MSparseArray_struct *MSparseArray;

typedef struct IMAGEOBJ_ENTRY *MImage;

#define MType_Integer 2
#define MType_Real 3
#define MType_Complex 4

typedef union {
	mbool *boolean;
	mint *integer;
	mreal *real;
	mcomplex *cmplex;
	MTensor *tensor;
	MSparseArray *sparse;
	MImage *image;
	char **utf8string;
} MArgument;

#define MArgument_getBooleanAddress(marg)		((marg).boolean)
#define MArgument_getIntegerAddress(marg)		((marg).integer)
#define MArgument_getRealAddress(marg)			((marg).real)
#define MArgument_getComplexAddress(marg)		((marg).cmplex)
#define MArgument_getMTensorAddress(marg)		((marg).tensor)
#define MArgument_getMSparseArrayAddress(marg)	((marg).sparse)
#define MArgument_getMImageAddress(marg)		((marg).image)
#define MArgument_getUTF8StringAddress(marg)	((marg).utf8string)

#define MArgument_getAddress(marg)				((void *) ((marg).integer))
#define MArgument_setAddress(marg, add)			(((marg).integer) = ((mint *) (add)))

#define MArgument_getBoolean(marg)				(*MArgument_getBooleanAddress(marg))
#define MArgument_getInteger(marg)				(*MArgument_getIntegerAddress(marg))
#define MArgument_getReal(marg)					(*MArgument_getRealAddress(marg))
#define MArgument_getComplex(marg)				(*MArgument_getComplexAddress(marg))
#define MArgument_getMTensor(marg)				(*MArgument_getMTensorAddress(marg))
#define MArgument_getMSparseArray(marg)			(*MArgument_getMSparseArrayAddress(marg))
#define MArgument_getMImage(marg)				(*MArgument_getMImageAddress(marg))
#define MArgument_getUTF8String(marg)			(*MArgument_getUTF8StringAddress(marg))

#define MArgument_setBoolean(marg, v)			((*MArgument_getBooleanAddress(marg)) = (v))
#define MArgument_setInteger(marg, v)			((*MArgument_getIntegerAddress(marg)) = (v))
#define MArgument_setReal(marg, v)				((*MArgument_getRealAddress(marg)) = (v))
#define MArgument_setComplex(marg, v)			((*MArgument_getComplexAddress(marg)) = (v))
#define MArgument_setMTensor(marg, v)			((*MArgument_getMTensorAddress(marg)) = (v))
#define MArgument_setMSparseArray(marg, v)		((*MArgument_getMSparseArrayAddress(marg)) = (v))
#define MArgument_setMImage(marg, v)			((*MArgument_getMImageAddress(marg)) = (v))
#define MArgument_setUTF8String(marg, v)		((*MArgument_getUTF8StringAddress(marg)) = (v))


#if defined(_WIN32) || defined(_WIN64)
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT
#endif

#endif


#ifndef EXTERN_C
#ifdef __cplusplus
#define EXTERN_C extern "C"
#else
#define EXTERN_C extern
#endif
#endif


#ifndef _MATHLINK_H
typedef struct MLINK_STRUCT* MLINK;
typedef struct MLENV_STRUCT* MLENV;
#define _MATHLINK_H
#endif

#ifndef MSTREAM_TYPEDEF
#define MSTREAM_TYPEDEF
typedef struct st_MInputStream *MInputStream;
typedef struct st_MOutputStream *MOutputStream;
#endif

/* Error types for LibraryErrorHandler */
enum {
	LIBRARY_NO_ERROR = 0,
	LIBRARY_TYPE_ERROR,
	LIBRARY_RANK_ERROR,
	LIBRARY_DIMENSION_ERROR,
	LIBRARY_NUMERICAL_ERROR,
	LIBRARY_MEMORY_ERROR,
	LIBRARY_FUNCTION_ERROR,
	LIBRARY_VERSION_ERROR
};

typedef struct st_DataStore *DataStore;

typedef struct st_WolframIOLibrary_Functions
{
	mint (*createAsynchronousTaskWithoutThread)();

	mint (*createAsynchronousTaskWithThread)(
		void (*asyncRunner)(mint asyncTaskID, void* initData),
		void* initData
	);

	void (*raiseAsyncEvent)(mint asyncTaskID, char* eventType, DataStore);

	mbool (*asynchronousTaskAliveQ)(mint asyncTaskID);
	mbool (*asynchronousTaskStartedQ)(mint asyncTaskID);

	DataStore (*createDataStore)(void);

	void (*DataStore_addInteger)(DataStore, mint);
	void (*DataStore_addReal)(DataStore, mreal);
	void (*DataStore_addComplex)(DataStore, mcomplex);
	void (*DataStore_addString)(DataStore, char*);
	void (*DataStore_addMTensor)(DataStore, MTensor);
	void (*DataStore_addDataStore)(DataStore, DataStore);

	void (*DataStore_addNamedInteger)(DataStore, char* name, mint);
	void (*DataStore_addNamedReal)(DataStore, char* name, mreal);
	void (*DataStore_addNamedComplex)(DataStore, char* name, mcomplex);
	void (*DataStore_addNamedString)(DataStore, char* name, char*);
	void (*DataStore_addNamedMTensor)(DataStore, char* name, MTensor);
	void (*DataStore_addNamedDataStore)(DataStore, char* name, DataStore);

} *WolframIOLibrary_Functions;

typedef struct st_WolframLibraryData* WolframLibraryData;

/* For backward compatibility with name change */
#define		getMathLink				getWSLINK
#define		processMathLink			processWSLINK
#define		getMathLinkEnvironment	getWSLINKEnvironment

struct st_WolframLibraryData
{
	void (*UTF8String_disown)(char *);

	int (*MTensor_new)(mint, mint, mint const*, MTensor *);
	void (*MTensor_free)( MTensor);
	int (*MTensor_clone)( MTensor, MTensor *);
	mint (*MTensor_shareCount)(MTensor);
	void (*MTensor_disown)( MTensor);
	void (*MTensor_disownAll)(MTensor);

	int (*MTensor_setInteger)(MTensor, mint*, mint);
	int (*MTensor_setReal)(MTensor, mint*, mreal);
	int (*MTensor_setComplex)(MTensor, mint*, mcomplex);
	int (*MTensor_setMTensor)(MTensor, MTensor, mint*, mint);

	int (*MTensor_getInteger)(MTensor, mint *, mint *);
	int (*MTensor_getReal)(MTensor, mint *, mreal *);
	int (*MTensor_getComplex)(MTensor, mint *, mcomplex *);
	int (*MTensor_getMTensor)(MTensor, mint *, mint, MTensor *);

	mint (*MTensor_getRank)( MTensor);
	mint const * (*MTensor_getDimensions)( MTensor);
	mint (*MTensor_getType)( MTensor);
	mint (*MTensor_getFlattenedLength)( MTensor);
	mint* (*MTensor_getIntegerData)( MTensor);
	mreal* (*MTensor_getRealData)( MTensor);
	mcomplex* (*MTensor_getComplexData)( MTensor);
	void (*Message)(const char *);
	mint (*AbortQ)(void);
	MLINK (*getWSLINK)(WolframLibraryData);
	int (*processWSLINK)(MLINK);
	int (*evaluateExpression)(WolframLibraryData, char *, int, mint, void *);
	struct st_WolframRuntimeData *runtimeData;
	struct st_WolframCompileLibrary_Functions *compileLibraryFunctions;
	mint VersionNumber;

	/* Added in WolframLibraryVersion 2 */
	mbool (*registerInputStreamMethod)(
		const char *name,
		void  (*ctor)(MInputStream, const char* msgHead, void* optionsIn),
		mbool (*handlerTest)(void*, char*),
		void* methodData,
		void  (*destroyMethod)(void* methodData)
	);

	mbool (*unregisterInputStreamMethod)(const char *name);

	mbool (*registerOutputStreamMethod)(
		const char *name,
		void  (*ctor)(MOutputStream, const char* msgHead, void* optionsIn, mbool appendMode),
		mbool (*handlerTest)(void*, char*),
		void* methodData,
		void  (*destroyMethod)(void* methodData)
	);

	mbool (*unregisterOutputStreamMethod)(const char *name);

	struct st_WolframIOLibrary_Functions* ioLibraryFunctions;
	MLENV (*getWSLINKEnvironment)(WolframLibraryData);
	struct st_WolframSparseLibrary_Functions *sparseLibraryFunctions;
	struct st_WolframImageLibrary_Functions *imageLibraryFunctions;

	int (*registerLibraryExpressionManager)(const char *mname, void (*mfun)(WolframLibraryData, mbool, mint));
	int (*unregisterLibraryExpressionManager)(const char *mname);
	int (*releaseManagedLibraryExpression)(const char *mname, mint id);

	int (*registerLibraryCallbackManager)(const char *name, mbool (*mfun)(WolframLibraryData, mint, MTensor));
	int (*unregisterLibraryCallbackManager)(const char *name);
	int (*callLibraryCallbackFunction)(mint id, mint ArgC, MArgument *Args, MArgument Res);
	int (*releaseLibraryCallbackFunction)(mint id);

	/* security callback */
	mbool (*validatePath)(char* path, char type);
	mbool (*protectedModeQ)(void);
};


#endif
