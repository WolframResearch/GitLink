/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include <stdlib.h>

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "GitLinkRepository.h"
#include "GitLinkCommit.h"
#include "GitLinkCommitRange.h"

#include "Message.h"
#include "MLHelper.h"
#include "RepoInterface.h"


GitLinkCommitRange::GitLinkCommitRange(const GitLinkRepository& repo) :
	repo_(repo), commitsValid_(true), revPushed_(false), revWalker_(NULL)
{
	if (repo.isValid() && git_revwalk_new(&revWalker_, repo.repo()) == 0)
		git_revwalk_sorting(revWalker_, GIT_SORT_TOPOLOGICAL);
	else
	{
		commitsValid_ = false;
		revWalker_ = NULL;
	}
}

GitLinkCommitRange::~GitLinkCommitRange()
{
	git_revwalk_free(revWalker_);
}

void GitLinkCommitRange::buildRange(MLINK link, long argCount)
{
	while (argCount-- > 0)
	{
		GitLinkCommit commit(repo_, link);
		addCommitSpecToRange(commit);
	}
}

void GitLinkCommitRange::writeRange(MLINK link)
{
	MLHelper helper(link);

	if (isValid())
	{
		git_oid oid;
		char sha[GIT_OID_HEXSZ + 1];
		helper.beginList();

		while (git_revwalk_next(&oid, revWalker_) == 0)
			helper.putGitObject(oid, repo_);
	}
	else
		helper.putSymbol("$Failed");

	// A successful walk automatically resets, so we'll just be consistent and reset
	// on unsuccessful walks, too.
	git_revwalk_reset(revWalker_);
	revPushed_ = false;
}

void GitLinkCommitRange::addCommitSpecToRange(const GitLinkCommit& commit)
{
	if (!commit.isValid())
		commitsValid_ = false;
	if (!commitsValid_)
		return;

	if (commit.isHidden())
		git_revwalk_hide(revWalker_, commit.oid());
	else
	{
		revPushed_ = true;
		git_revwalk_push(revWalker_, commit.oid());
	}
}
