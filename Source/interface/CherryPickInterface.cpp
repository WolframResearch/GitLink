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


EXTERN_C DLLEXPORT int GitCherryPick(WolframLibraryData libData, MLINK lnk)
{
	bool success = false;
	long argCount;
	MLCheckFunction(lnk, "List", &argCount);

	GitLinkRepository repo(lnk);
	GitLinkCommit commit(repo, lnk);

	if (commit.isValid())
	{
		git_cherry_pick_options opts;
		git_cherry_pick_init_options(&opts, GIT_CHERRY_PICK_OPTIONS_VERSION);
		success = (git_cherry_pick(repo.repo(), commit.commit(), &opts) == 0);
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
	const char* branch;
	int branchStringLen;
	int unused;
	MLGetUTF8String(lnk, (const unsigned char **)&branch, &branchStringLen, &unused);

	if (pickedCommit.isValid() && pickedCommit.parentCount() == 1 && parentCommit.isValid())
	{
		git_merge_options opts;
		git_index* index;
		int pickErr;

		git_merge_init_options(&opts, GIT_MERGE_OPTIONS_VERSION);
		pickErr = git_cherry_pick_commit(&index, repo.repo(), pickedCommit.commit(), parentCommit.commit(), 0, &opts);

		if (!pickErr)
		{
			GitLinkCommit newCommit(repo, index, parentCommit, pickedCommit.author(), pickedCommit.message());
			if (newCommit.isValid())
			{
				newCommit.writeSHA(lnk);
				success = true;
				if (strcmp(branch, "None") != 0)
				{
					git_reference* ref;
					git_branch_create(&ref, repo.repo(), branch, newCommit.commit(), true, repo.committer(), NULL);
					git_reference_free(ref);
				}
			}
			else
				newCommit.mlWriteMessagePacket(libData, lnk, "CherryPick");
			git_index_free(index);
		}
	}
	if (!success)
		MLPutSymbol(lnk, "$Failed");

	MLReleaseUTF8String(lnk, (const unsigned char*)branch, branchStringLen);

	return LIBRARY_NO_ERROR;
}
