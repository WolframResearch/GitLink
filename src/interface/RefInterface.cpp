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
#include "CommitInterface.h"
#include "GitLinkRepository.h"
#include "GitLinkCommit.h"
#include "Message.h"


EXTERN_C DLLEXPORT int GitCreateBranch(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString branchName(lnk);
	GitLinkCommit commit(repo, lnk);
	MLString forceIt(lnk);

	bool force = (strcmp(forceIt, "True") == 0);
	if (commit.createBranch(branchName, force))
		MLPutSymbol(lnk, "True");
	else
	{
		commit.mlHandleError(libData, "GitCreateBranch");
		MLPutSymbol(lnk, "False");
	}

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitDeleteBranch(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString branchName(lnk);
	MLString forceIt(lnk);
	bool force = (strcmp(forceIt, "True") == 0);
	git_reference* branchRef;

	if (!repo.isValid())
	{
		MLHandleError(libData, "GitDeleteBranch", Message::BadRepo);
		MLPutSymbol(lnk, "$Failed");
	}
	else if (git_branch_lookup(&branchRef, repo.repo(), branchName, GIT_BRANCH_LOCAL) != 0)
	{
		MLHandleError(libData, "GitDeleteBranch", Message::NoLocalBranch);
		MLPutSymbol(lnk, "$Failed");
	}
	else
	{
		MLPutSymbol(lnk, (git_branch_delete(branchRef) == 0) ? "Null" : "$Failed");
		git_reference_free(branchRef);
	}

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitUpstreamBranch(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString branchName(lnk);

	git_reference* branchRef = NULL;
	git_reference* upstreamBranchRef = NULL;
	const char* err = NULL;

	if (!repo.isValid())
		err = Message::BadRepo;
	else if (git_branch_lookup(&branchRef, repo.repo(), branchName, GIT_BRANCH_LOCAL) != 0)
		err = Message::NoLocalBranch;

	if (err)
	{
		MLHandleError(libData, "GitUpstreamBranch", err);
		MLPutSymbol(lnk, "$Failed");
		return LIBRARY_NO_ERROR;
	}

	int result = git_branch_upstream(&upstreamBranchRef, branchRef);
	if (result == GIT_ENOTFOUND)
		MLPutSymbol(lnk, "None");
	else if (result == 0)
	{
		const char* upstreamBranchName;
		git_branch_name(&upstreamBranchName, upstreamBranchRef);
		MLPutUTF8String(lnk, (const unsigned char*) upstreamBranchName, (int) strlen(upstreamBranchName));
	}
	else
	{
		MLHandleError(libData, "GitUpstreamBranch", Message::UpstreamFailed);
		MLPutSymbol(lnk, "$Failed");
	}

	if (upstreamBranchRef)
		git_reference_free(upstreamBranchRef);
	if (branchRef)
		git_reference_free(branchRef);

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitSetUpstreamBranch(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString branchName(lnk);
	MLString upstreamBranch(lnk);

	git_reference* branchRef = NULL;
	const char* err = NULL;

	if (!repo.isValid())
		err = Message::BadRepo;
	else if (git_branch_lookup(&branchRef, repo.repo(), branchName, GIT_BRANCH_LOCAL) != 0)
		err = Message::NoLocalBranch;
	else if (git_branch_set_upstream(branchRef, upstreamBranch) != 0)
		err = Message::SetUpstreamFailed;

	if (branchRef)
		git_reference_free(branchRef);

	MLHandleError(libData, "GitSetUpstreamBranch", err);
	MLPutSymbol(lnk, (err == NULL) ? "True" : "False");

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitType(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString sha(lnk);
	git_oid oid;
	git_object* object;
	git_otype otype = GIT_OBJ_BAD;

	if (!git_oid_fromstr(&oid, sha) && !git_object_lookup(&object, repo.repo(), &oid, GIT_OBJ_ANY))
	{
		otype = git_object_type(object);
		git_object_free(object);
	}

	switch(otype)
	{
		case GIT_OBJ_COMMIT:	MLPutString(lnk, "Commit");			break;
		case GIT_OBJ_TREE:		MLPutString(lnk, "Tree");			break;
		case GIT_OBJ_BLOB:		MLPutString(lnk, "Blob");			break;
		case GIT_OBJ_TAG:		MLPutString(lnk, "AnnotatedTag");	break;
		case GIT_OBJ_OFS_DELTA:	MLPutString(lnk, "OffsetDelta");	break;
		case GIT_OBJ_REF_DELTA:	MLPutString(lnk, "ObjectDelta");	break;
		default:				MLPutSymbol(lnk, "None");			break;
	}

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int ToGitObject(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLString name(lnk);

	GitLinkCommit commit(repo, name);
	git_oid oid;
	git_object* object = NULL;

	if (!repo.isValid())
		MLPutSymbol(lnk, "$Failed");
	else if (commit.isValid())
		commit.write(lnk);
	else if (!git_oid_fromstrp(&oid, name) && !git_object_lookup(&object, repo.repo(), &oid, GIT_OBJ_ANY))
	{
		char sha[GIT_OID_HEXSZ+1];
		MLHelper helper(lnk);
		git_oid_tostr(sha, GIT_OID_HEXSZ + 1, &oid);
		helper.beginFunction("GitObject");
		helper.putString(sha);
		helper.putRepo(repo);
	}
	else
		MLPutSymbol(lnk, "$Failed");

	return LIBRARY_NO_ERROR;
}
