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
#include "GitLinkCommitRange.h"
#include "GitTree.h"
#include "Message.h"
#include "Signature.h"


EXTERN_C DLLEXPORT int GitCommitQ(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	GitLinkCommit commit(repo, lnk);

	MLPutSymbol(lnk, commit.isValid() ? "True" : "False");

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitSHA(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	GitLinkCommit commit(repo, lnk);

	commit.writeSHA(lnk);

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitCommitProperties(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	GitLinkCommit commit(repo, lnk);

	commit.writeProperties(lnk);

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitCommit(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);
	GitLinkRepository repo(lnk);
	MLString message(lnk);
	GitTree tree(lnk);
	MLExpr parentsExpr(lnk);
	Signature author(repo, lnk);
	Signature committer(repo, lnk);
	git_oid treeSHA;

	if (!repo.isValid())
	{
		repo.mlHandleError(libData, "GitCommit");
		MLPutSymbol(lnk, "$Failed");
		return LIBRARY_NO_ERROR;
	}

	GitLinkCommitDeque parents(repo, parentsExpr);
	if (!parents.isValid())
	{
		parents.mlHandleError(libData, "GitCommit");
		MLPutSymbol(lnk, "$Failed");
	}
	else
	{
		GitLinkCommit commit(repo, tree, parents, author, committer, message);
		if (!commit.isValid())
			commit.mlHandleError(libData, "GitCommit");
		commit.write(lnk);
	}

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitRange(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLExpr lengthOnly(lnk);
	GitLinkCommitRange range(repo);

	range.buildRange(lnk, argCount - 2);
	range.writeRange(lnk, lengthOnly.testSymbol("True"));

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitMergeBase(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	std::vector<GitLinkCommit> commits;
	argCount--;
	while (argCount-- > 0)
		commits.push_back(GitLinkCommit(repo, lnk));

	for (const auto& commit : commits)
	{
		if (!commit.isValid())
		{
			commit.mlHandleError(libData, "GitMergeBase");
			MLPutSymbol(lnk, "$Failed");
			return LIBRARY_NO_ERROR;
		}
	}

	std::vector<git_oid> oidArray(commits.size());
	for (int i = 0; i < commits.size(); i++)
		git_oid_cpy(&oidArray[i], commits[i].oid());

	git_oid result;
	if (git_merge_base_many(&result, repo.repo(), commits.size(), oidArray.data()) == 0)
		GitLinkCommit(repo, &result).write(lnk);
	else
		MLPutSymbol(lnk, "None");

	return LIBRARY_NO_ERROR;
}

EXTERN_C DLLEXPORT int GitAheadBehind(WolframLibraryData libData, MLINK lnk)
{
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	MLExpr commit1Expr(lnk);
	MLExpr commit2Expr(lnk);

	GitLinkCommit commit1(repo, commit1Expr);
	GitLinkCommit commit2(repo, commit2Expr);

	size_t ahead, behind;

	const char* error = NULL;
	const char* param = NULL;
	if (!repo.isValid())
		error = Message::BadRepo;
	else if (!commit1.isValid() || !commit2.isValid())
		error = Message::BadCommitish;
	else if (git_graph_ahead_behind(&ahead, &behind, repo.repo(), commit1.oid(), commit2.oid()) != 0)
	{
		error = Message::GitOperationFailed;
		param = giterr_last() ? giterr_last()->message : NULL;
	}

	if (error)
	{
		MLHandleError(libData, "GitAheadBehind", error, param);
		MLPutSymbol(lnk, "$Failed");
	}
	else
	{
		MLPutFunction(lnk, "List", 2);
		MLPutInteger(lnk, ahead);
		MLPutInteger(lnk, behind);
	}

	return LIBRARY_NO_ERROR;
}

