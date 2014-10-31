/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "RepoInterface.h"


/* Return the version of Library Link */
EXTERN_C DLLEXPORT mint WolframLibrary_getVersion()
{
	return WolframLibraryVersion;
}

/* Initialize Library */
EXTERN_C DLLEXPORT int WolframLibrary_initialize(WolframLibraryData libData)
{
	git_threads_init();
	return libData->registerLibraryExpressionManager("gitRepo", manageRepoInstance);
}

/* Uninitialize Library */
EXTERN_C DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData)
{
	git_threads_shutdown();
	int err = libData->unregisterLibraryExpressionManager("gitRepo");
}

EXTERN_C DLLEXPORT int libGitVersion(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument res)
{
	int major, minor, rev;
	int err;
	MTensor version;
	mint pos = 1;
	mint len = 3;

	git_libgit2_version(&major, &minor, &rev);
	err = libData->MTensor_new(MType_Integer, 1, &len, &version);
	libData->MTensor_setInteger(version, &pos, major); pos++;
	libData->MTensor_setInteger(version, &pos, minor); pos++;
	libData->MTensor_setInteger(version, &pos, rev);
	MArgument_setMTensor(res, version);

	return err;
}

EXTERN_C DLLEXPORT int libGitFeatures(WolframLibraryData libData, MLINK lnk)
{
	int features = git_libgit2_features();
	int threads = ((features & GIT_FEATURE_THREADS) == 0) ? 0 : 1;
	int https = ((features & GIT_FEATURE_HTTPS) == 0) ? 0 : 1;
	int ssh = ((features & GIT_FEATURE_SSH) == 0) ? 0 : 1;
	long argCount;

	MLCheckFunction(lnk, "List", &argCount);
	
	MLPutFunction(lnk, "List", threads + https + ssh);
	if (threads)
		MLPutString(lnk, "Threads");
	if (https)
		MLPutString(lnk, "Https");
	if (ssh)
		MLPutString(lnk, "Ssh");

	return LIBRARY_NO_ERROR;
}

