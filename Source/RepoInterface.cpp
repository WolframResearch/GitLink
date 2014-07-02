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

EXTERN_C DLLEXPORT int GitRemoteQ(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument res)
{
	bool returnValue = false;
	if (Argc >= 2)
	{
		GitLinkRepository repo(MArgument_getInteger(Args[0]));
		if (repo.isValid())
		{
			git_remote* remote;
			const char* remoteName;

			remoteName = MArgument_getUTF8String(Args[1]);
			if (git_remote_load(&remote, repo.repo(), remoteName) == 0)
			{
				git_remote_free(remote);
				returnValue = true;
			}
			libData->UTF8String_disown((char*)remoteName);
		}
	}
	MArgument_setBoolean(res, returnValue);
	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitBranchQ(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument res)
{
	bool returnValue = false;
	if (Argc >= 2)
	{
		GitLinkRepository repo(MArgument_getInteger(Args[0]));
		if (repo.isValid())
		{
			git_reference* reference;
			const char* branchName;

			branchName = MArgument_getUTF8String(Args[1]);
			if (git_branch_lookup(&reference, repo.repo(), branchName, GIT_BRANCH_LOCAL) == 0)
			{
				git_reference_free(reference);
				returnValue = true;
			}
			libData->UTF8String_disown((char*)branchName);
		}
	}
	MArgument_setBoolean(res, returnValue);
	return LIBRARY_NO_ERROR;
}

