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
#include "RepoStatus.h"
#include "Signature.h"
#include "CheckoutManager.h"


std::unordered_map<mint, git_repository *> ManagedRepoMap;

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
		if (returnValue == NULL) // e.g., a bare repo
			returnValue = git_repository_path(repo.repo());
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
	MLExpr doRenames(lnk);
	MLExpr doIgnored(lnk);
	MLExpr recurseUntrackedDirs(lnk);

	RepoStatus status(repo, doRenames.asBool(), doIgnored.asBool(), recurseUntrackedDirs.asBool());

	if (status.isValid())
		status.writeStatus(lnk);
	else
		MLPutSymbol(lnk, "$Failed");
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
			if (git_remote_lookup(&remote, repo.repo(), remoteName) == 0)
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
	MLExpr progressFunction(lnk);

	RemoteConnector connector(libData, privateKeyFile);

	git_repository* lgRepo;
	git_clone_options cloneOptions;
	git_clone_init_options(&cloneOptions, GIT_CLONE_OPTIONS_VERSION);
	cloneOptions.bare = (bool) bare;

	if (connector.clone(&lgRepo, uri, localPath, &cloneOptions, progressFunction) && !libData->AbortQ())
	{
		GitLinkRepository repo(lgRepo, libData);
		repo.mlHandleError(libData, "GitClone");

		MLHelper helper(lnk);
		helper.putRepo(repo);
	}
	else if (!libData->AbortQ())
	{
		MLHandleError(libData, "GitClone", Message::FetchFailed, strdup(giterr_last()->message));
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
	MLExpr prune(lnk);
	bool result = repo.fetch(libData, remote, privateKeyFile, prune);
	repo.mlHandleError(libData, "GitFetch");
	MLPutSymbol(lnk, result ? "True" : "False");
	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitInit(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	MLString repoPath(lnk);
	MLExpr workingDirPath(lnk);
	MLExpr bare(lnk);
	MLExpr description(lnk);
	MLExpr overwrite(lnk);

	git_repository* repo;
	git_repository_init_options options;

	git_repository_init_init_options(&options, GIT_REPOSITORY_INIT_OPTIONS_VERSION);

	options.flags = GIT_REPOSITORY_INIT_MKDIR | GIT_REPOSITORY_INIT_MKPATH;
	if (!overwrite.testSymbol("True"))
		options.flags |= GIT_REPOSITORY_INIT_NO_REINIT;
	if (bare.testSymbol("True"))
		options.flags |= GIT_REPOSITORY_INIT_BARE;

	options.mode = GIT_REPOSITORY_INIT_SHARED_GROUP;

	if (description.isString() && !description.testString(""))
		options.description = description.asString();

	if (workingDirPath.isString() && !workingDirPath.testString(""))
		options.workdir_path = workingDirPath.asString();

	int err = git_repository_init_ext(&repo, repoPath, &options);
	switch (err)
	{
		case 0:
		{
			MLHelper helper(lnk);
			helper.putRepo(GitLinkRepository(repo, libData));
			return LIBRARY_NO_ERROR;
		}
		case GIT_EEXISTS:
			MLHandleError(libData, "GitInit", Message::RepoExists, repoPath);
			break;
		default:
			MLHandleError(libData, "GitInit", Message::GitOperationFailed, strdup(giterr_last()->message));
			break;
	}
	MLPutSymbol(lnk, "$Failed");
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

	bool result = repo.push(libData, remote, privateKeyFile, branch);
	repo.mlHandleError(libData, "GitPush");
	MLPutSymbol(lnk, result ? "True" : "False");

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitSetHead(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString refName(lnk);

	bool result = repo.setHead(refName);
	repo.mlHandleError(libData, "GitSetHead");
	if (result)
		GitLinkCommit(repo, refName).write(lnk);
	else
		MLPutSymbol(lnk, "$Failed");

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitCheckoutHead(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLExpr strategy(lnk);
	MLExpr notifyFlags(lnk);

	bool result = repo.checkoutHead(libData, strategy, notifyFlags);
	repo.mlHandleError(libData, "GitCheckoutHead");
	MLPutSymbol(lnk, result ? "True" : "False");

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitCheckoutReference(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString reference(lnk);

	CheckoutManager manager(repo);
	GitTree refTree(repo, reference);

	if (manager.initCheckout(libData, reference, refTree) && manager.doCheckout(refTree))
		GitLinkCommit(repo, "HEAD").write(lnk);
	else
	{
		manager.mlHandleError(libData, "GitCheckoutReference");
		MLPutSymbol(lnk, "$Failed");
	}

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

	mergeFactory.write(lnk);
	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitSignature(WolframLibraryData libData, MLINK lnk)
{
	MLExpr argv(lnk);
	Signature signature(argv);

	signature.writeAssociation(lnk);
	return LIBRARY_NO_ERROR;
}

// FIXME: Not enough error-reporting here yet
EXTERN_C DLLEXPORT int GitAddRemote(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);
	GitLinkRepository repo(lnk);
	MLString remoteName(lnk);
	MLString uri(lnk);
	git_remote* remote;
	bool success = false;

	if (!git_remote_is_valid_name(remoteName))
	{
		MLHandleError(libData, "GitAddRemote", Message::BadRemoteName, NULL);
	}
	else if (!repo.isValid())
		repo.mlHandleError(libData, "GitAddRemote");
	else if (git_remote_create(&remote, repo.repo(), remoteName, uri))
		MLHandleError(libData, "GitAddRemote", Message::GitOperationFailed, NULL);
	else
	{
		MLHelper helper(lnk);
		repo.writeRemotes(helper);
		git_remote_free(remote);
		return LIBRARY_NO_ERROR;
	}

	MLPutSymbol(lnk, "$Failed");
	return LIBRARY_NO_ERROR;
}

// FIXME: Not enough error-reporting here yet
EXTERN_C DLLEXPORT int GitDeleteRemote(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);
	GitLinkRepository repo(lnk);
	MLString remoteName(lnk);
	git_remote* remote = NULL;
	bool success = false;

	if (!repo.isValid())
		repo.mlHandleError(libData, "GitDeleteRemote");
	else if (git_remote_delete(repo.repo(), remoteName))
		MLHandleError(libData, "GitDeleteRemote", Message::BadRemote, NULL);
	else
	{
		MLHelper helper(lnk);
		repo.writeRemotes(helper);
		git_remote_free(remote);
		return LIBRARY_NO_ERROR;
	}

	if (remote)
		git_remote_free(remote);
	MLPutSymbol(lnk, "$Failed");
	return LIBRARY_NO_ERROR;
}
