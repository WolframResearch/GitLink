/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

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
	return libData->registerLibraryExpressionManager("gitRepo", manageRepoInstance);
}

/* Uninitialize Library */
EXTERN_C DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData libData)
{
	int err = libData->unregisterLibraryExpressionManager("gitRepo");
}

