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
#include "GitLinkRepository.h"


stdext::hash_map<mint, git_repository *> ManagedRepoMap;

DLLEXPORT void manageRepoInstance(WolframLibraryData libData, mbool mode, mint id)
{
	if (mode == 0)
		ManagedRepoMap[id] = NULL;
	else
	{
		GitLinkRepository repo(id);
		repo.unsetKey();
		ManagedRepoMap.erase(id);
	}
}

EXTERN_C DLLEXPORT int assignToManagedRepoInstance(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument res)
{
	GitLinkRepository repo(libData, Argc, Args);
	mint id = (Argc >= 2) ? MArgument_getInteger(Args[1]) : BAD_KEY;
	const char* returnValue = "";

	if (repo.isValid() && id != BAD_KEY)
	{
		repo.setKey(id);
		returnValue = git_repository_workdir(repo.repo());
	}

	MArgument_setUTF8String(res, (char*) returnValue);
	
	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitRepoQ(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument res)
{
	GitLinkRepository repo(libData, Argc, Args);
	MArgument_setBoolean(res, repo.isValid());
	return LIBRARY_NO_ERROR;
}
