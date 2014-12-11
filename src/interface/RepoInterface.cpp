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
#include "GitLinkRepository.h"
#include "MergeFactory.h"
#include "Message.h"


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

EXTERN_C DLLEXPORT int assignToManagedRepoInstance(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);
	GitLinkRepository repo(lnk);
	mint id = BAD_KEY;
	const char* returnValue = "";

	if (argCount >= 2)
		MLGetMint(lnk, &id);

	if (repo.isValid() && id != BAD_KEY)
	{
		repo.setKey(id);
		returnValue = git_repository_workdir(repo.repo());
	}

	MLPutUTF8String(lnk, (const unsigned char*) returnValue, strlen(returnValue));
	
	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitProperties(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);

	repo.writeProperties(lnk);

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitStatus(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);

	repo.writeStatus(lnk);

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitRepoQ(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLPutSymbol(lnk, repo.isValid() ? "True" : "False");

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

EXTERN_C DLLEXPORT int GitClone(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	MLString uri(lnk);
	MLString localPath(lnk);
	MLString privateKeyFile(lnk);
	MLBoolean bare(lnk);

	RemoteConnector connector(privateKeyFile);

	git_repository* lgRepo;
	git_clone_options cloneOptions;
	git_clone_init_options(&cloneOptions, GIT_CLONE_OPTIONS_VERSION);
	cloneOptions.bare = (bool) bare;

	if (connector.clone(&lgRepo, uri, localPath, &cloneOptions))
	{
		GitLinkRepository repo(lgRepo, libData);
		repo.mlHandleError(libData, "GitClone");

		MLHelper helper(lnk);
		helper.putRepo(repo);
	}
	else
	{
		MLHandleError(libData, "GitClone", Message::FetchFailed, giterr_last()->message);
		MLPutSymbol(lnk, "$Failed");
	}

	return LIBRARY_NO_ERROR;
}


EXTERN_C DLLEXPORT int GitFetch(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString remote(lnk);
	MLString privateKeyFile(lnk);
	MLString pruneString(lnk);
	bool prune = (strcmp(pruneString, "True") == 0);
	bool result = repo.fetch(remote, privateKeyFile, prune);
	repo.mlHandleError(libData, "GitFetch");
	MLPutSymbol(lnk, result ? "True" : "False");
	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitPush(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString remote(lnk);
	MLString privateKeyFile(lnk);
	MLString branch(lnk);

	bool result = repo.push(lnk, remote, privateKeyFile, branch);
	repo.mlHandleError(libData, "GitPush");
	MLPutSymbol(lnk, result ? "True" : "False");

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitMerge(WolframLibraryData libData, MLINK lnk)
{
	MLExpr argv(lnk);
	MergeFactory mergeFactory(argv);

	if (!mergeFactory.initialize(eMergeTypeMerge))
		mergeFactory.mlHandleError(libData, "GitMerge");
	else
		mergeFactory.doMerge(libData);

	mergeFactory.writeSHAOrFailure(lnk);
	return LIBRARY_NO_ERROR;
}

