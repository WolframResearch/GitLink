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
#include "GitLinkRepository.h"
#include "GitLinkCommit.h"
#include "GitLinkCommitRange.h"
#include "Message.h"
#include "GitTree.h"
#include "Signature.h"


EXTERN_C DLLEXPORT int GitCherryPick(WolframLibraryData libData, MLINK lnk)
{
	bool success = false;
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	GitLinkCommit commit(repo, lnk);

	if (commit.isValid())
	{
		git_cherrypick_options opts;
		git_cherrypick_init_options(&opts, GIT_CHERRYPICK_OPTIONS_VERSION);
		success = (git_cherrypick(repo.repo(), commit.commit(), &opts) == 0);
	}
	MLPutSymbol(lnk, success ? "True" : "False");

	return LIBRARY_NO_ERROR;
}


EXTERN_C DLLEXPORT int GitCherryPickCommit(WolframLibraryData libData, MLINK lnk)
{
	bool success = false;
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	GitLinkCommit pickedCommit(repo, lnk);
	GitLinkCommit parentCommit(repo, lnk);
	MLString branch(lnk);

	if (pickedCommit.isValid() && pickedCommit.parentCount() == 1 && parentCommit.isValid())
	{
		git_merge_options opts;
		git_index* index;
		int pickErr;

		git_merge_init_options(&opts, GIT_MERGE_OPTIONS_VERSION);
		opts.flags = (git_merge_flag_t) (opts.flags | GIT_MERGE_FAIL_ON_CONFLICT);
		pickErr = git_cherrypick_commit(&index, repo.repo(), pickedCommit.commit(), parentCommit.commit(), 0, &opts);

		if (!pickErr)
		{
			GitTree tree(repo, index);
			GitLinkCommit newCommit(repo, tree, parentCommit, pickedCommit.author(), NULL, pickedCommit.message());
			if (newCommit.isValid())
			{
				newCommit.write(lnk);
				success = true;
				if (strcmp(branch, "None") != 0)
				{
					git_reference* ref;
					git_branch_create(&ref, repo.repo(), branch, newCommit.commit(), true);
					git_reference_free(ref);
				}
			}
			else
				newCommit.mlHandleError(libData, "CherryPick");
		}
		git_index_free(index);
	}
	if (!success)
		MLPutSymbol(lnk, "$Failed");

	return LIBRARY_NO_ERROR;
}
