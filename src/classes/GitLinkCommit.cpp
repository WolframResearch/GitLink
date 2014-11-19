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

#include "Message.h"
#include "MLHelper.h"
#include "RepoInterface.h"


GitLinkCommit::GitLinkCommit(const GitLinkRepository& repo, MLExpr expr)
	: repo_(repo)
	, valid_(false)
	, notSpec_(false)
	, commit_(NULL)
{
	MLExpr currentExpr = expr;
	while (currentExpr.testHead("Not") && currentExpr.length() == 1)
	{
		notSpec_ = !notSpec_;
		currentExpr = currentExpr.part(1);
		continue;
	}
	if (currentExpr.isString())
	{
		git_object* obj;
		if (git_revparse_single(&obj, repo_.repo(), currentExpr.asString()) == 0)
		{
			if (git_object_type(obj) == GIT_OBJ_COMMIT)
			{
				valid_ = true;
				git_oid_cpy(&oid_, git_object_id(obj));
			}
		}
	}

	if (!valid_)
		errCode_ = repo.isValid() ? Message::BadCommitish : Message::BadRepo;
}

GitLinkCommit::GitLinkCommit(const GitLinkRepository& repo, git_index* index, GitLinkCommit& parent,
								const git_signature* author, const char* message)
	: repo_(repo)
	, valid_(false)
	, notSpec_(false)
	, commit_(NULL)
{
	const git_signature* committer = repo.committer();

	if (!repo.isValid())
		errCode_ = Message::BadRepo;
	else if (!parent.isValid())
		errCode_ = Message::NoParent;
	else if (!index)
		errCode_ = Message::NoIndex;
	else if (!message)
		errCode_ = Message::NoMessage;
	else if (git_index_has_conflicts(index))
		errCode_ = Message::HasConflicts;
	else if (committer == NULL)
		errCode_ = Message::NoDefaultUserName;
	else
	{
		git_oid treeId;
		if (author == NULL)
			author = committer;

		if (!git_index_write_tree_to(&treeId, index, repo.repo()))
		{
			git_tree* newTree;
			const git_commit* parentCommit = parent.commit();
			git_tree_lookup(&newTree, repo.repo(), &treeId);
			if (!git_commit_create(&oid_, repo.repo(), NULL, author, committer, NULL, message, newTree, 1, &parentCommit))
				valid_ = true;
			else
				errCode_ = Message::GitCommitError;
		}
		else
			errCode_ = Message::CantWriteTree;
	}
}

GitLinkCommit::GitLinkCommit(const GitLinkCommit& commit)
	: repo_(commit.repo_)
	, valid_(commit.valid_)
	, notSpec_(commit.notSpec_)
	, commit_(NULL)
{

}

GitLinkCommit::~GitLinkCommit()
{
	if (commit_)
		git_commit_free(commit_);
}

void GitLinkCommit::writeProperties(MLINK lnk)
{
	MLHelper helper(lnk);
	const git_commit* theCommit = commit();

	if (!isValid() || theCommit == NULL)
	{
		helper.putString(Message::BadCommitish);
		return;
	}

	helper.beginFunction("Association");

	helper.putRule("Parents");
	helper.beginList();
	for (int i = 0; i < git_commit_parentcount(theCommit); i++)
		helper.putOid(*git_commit_parent_id(theCommit, i));
	helper.endList();

	helper.putRule("Tree", *git_commit_tree_id(theCommit));
	helper.putRule("AuthorName", git_commit_author(theCommit)->name);
	helper.putRule("AuthorEmail", git_commit_author(theCommit)->email);
	helper.putRule("AuthorTime", git_commit_author(theCommit)->when);
	helper.putRule("AuthorTimeZone", (double) git_commit_author(theCommit)->when.offset / 60.);
	helper.putRule("CommitterName", git_commit_committer(theCommit)->name);
	helper.putRule("CommitterEmail", git_commit_committer(theCommit)->email);
	helper.putRule("CommitterTime", git_commit_committer(theCommit)->when);
	helper.putRule("CommitterTimeZone", (double) git_commit_committer(theCommit)->when.offset / 60.);
	helper.putRule("SHA", *git_commit_id(theCommit));
	helper.putRule("Message", git_commit_message_raw(theCommit));
}

void GitLinkCommit::writeSHA(MLINK lnk) const
{
	char buf[GIT_OID_HEXSZ + 1];
	if (valid_)
	{
		git_oid_tostr(buf, GIT_OID_HEXSZ + 1, &oid_);
		MLPutString(lnk, buf);
	}
	else
		MLPutString(lnk, Message::BadCommitish);
}

git_commit* GitLinkCommit::commit()
{
	if (commit_)
		return commit_;
	if (!isValid())
		return NULL;
	if (git_commit_lookup(&commit_, repo_.repo(), &oid_) || commit_ == NULL)
	{
		valid_ = false;
		return NULL;
	}
	return commit_;
}

bool GitLinkCommit::createBranch(const char* branchName, bool force)
{
	// no need to set error...the constructor already set it in this case
	if (!isValid())
		return false;

	errCode_ = errCodeParam_ = NULL;
	git_reference* ref;

	const git_signature* committer = repo_.committer();
	if (committer == NULL)
	{
		errCode_ = Message::NoDefaultUserName;
		return false;
	}
	int err = git_branch_create(&ref, repo_.repo(), branchName, commit(), force, committer, NULL);
	if (err == GIT_EINVALIDSPEC)
		errCode_ = Message::InvalidSpec;
	else if (err == GIT_EEXISTS)
		errCode_ = Message::RefExists;
	else if (err != 0)
	{
		errCode_ = Message::BranchNotCreated;
		errCodeParam_ = giterr_last()->message;
	}

	if (!err)
		git_reference_free(ref);
	return (err == 0);
}

int GitLinkCommit::parentCount()
{
	const git_commit* theCommit = commit();

	if (!isValid() || theCommit == NULL)
		return 0;
	return git_commit_parentcount(theCommit);
}
