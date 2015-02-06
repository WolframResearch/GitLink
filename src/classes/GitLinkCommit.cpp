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
#include "GitTree.h"
#include "Signature.h"

#include "Message.h"
#include "MLHelper.h"
#include "RepoInterface.h"


GitLinkCommit::GitLinkCommit(const GitLinkRepository& repo, const MLExpr& expr)
	: repoKey_(repo.key())
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
	if (currentExpr.testHead("GitObject") && currentExpr.length() == 2 && currentExpr.part(1).isString())
		currentExpr = currentExpr.part(1);
	if (currentExpr.isString())
	{
		git_object* obj;
		if (git_revparse_single(&obj, repo.repo(), currentExpr.asString()) == 0)
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

GitLinkCommit::GitLinkCommit(const GitLinkRepository& repo, const char* refName)
	: repoKey_(repo.key())
	, valid_(false)
	, notSpec_(false)
	, commit_(NULL)
{
	git_object* obj;
	if (git_revparse_single(&obj, repo.repo(), refName) == 0)
	{
		if (git_object_type(obj) == GIT_OBJ_COMMIT)
		{
			valid_ = true;
			git_oid_cpy(&oid_, git_object_id(obj));
		}
	}

	if (!valid_)
		errCode_ = repo.isValid() ? Message::BadCommitish : Message::BadRepo;
}

GitLinkCommit::GitLinkCommit(const GitLinkRepository& repo, const git_oid* oid)
	: repoKey_(repo.key())
	, valid_(true)
	, notSpec_(false)
	, commit_(NULL)
{
	git_oid_cpy(&oid_, oid);
	commit(); // does validity check
}

GitLinkCommit::GitLinkCommit(const GitLinkRepository& repo, const GitTree& tree, const GitLinkCommitDeque& parents,
								const git_signature* author, const git_signature* committer, const char* message)
	: repoKey_(repo.key())
	, valid_(false)
	, notSpec_(false)
	, commit_(NULL)
{
	if (committer == NULL)
		committer = repo.committer();
	if (author == NULL)
		author = committer;

	if (!repo.isValid())
		errCode_ = Message::BadRepo;
	else if (!tree.isValid())
		errCode_ = Message::NoTree;
	else if (!message)
		errCode_ = Message::NoMessage;
	else if (committer == NULL)
		errCode_ = Message::NoDefaultUserName;
	else if (!parents.isValid())
		errCode_ = Message::NoParent;
	else
	{
		if (!git_commit_create(&oid_, repo.repo(), NULL, author, committer,
								NULL, message, tree, parents.size(), parents.commits()))
			valid_ = true;
		else
			errCode_ = Message::GitCommitError;
	}
}

GitLinkCommit::GitLinkCommit(const GitLinkCommit& commit)
	: repoKey_(commit.repoKey_)
	, valid_(commit.valid_)
	, notSpec_(commit.notSpec_)
	, commit_(NULL)
{
	errCode_ = commit.errCode_;
	git_oid_cpy(&oid_, &commit.oid_);
}

GitLinkCommit::~GitLinkCommit()
{
	if (commit_)
		git_commit_free(commit_);
}

bool GitLinkCommit::operator==(GitLinkCommit& c)
{
	commit();
	c.commit();
	if (!isValid() || !c.isValid())
		return false;
	return git_oid_cmp(oid(), c.oid()) == 0;
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

	helper.putRule("Type");
	helper.putString("Commit");
	
	helper.putRule("Parents");
	helper.beginList();
	for (int i = 0; i < git_commit_parentcount(theCommit); i++)
		helper.putGitObject(*git_commit_parent_id(theCommit, i), repoKey_);
	helper.endList();

	Signature author(git_commit_author(theCommit));
	Signature committer(git_commit_committer(theCommit));

	helper.putRule("Tree");
	helper.putGitObject(*git_commit_tree_id(theCommit), repoKey_);
	helper.putRule("Author");
	author.writeAssociation(helper);
	helper.putRule("Committer");
	committer.writeAssociation(helper);
	helper.putRule("SHA", *git_commit_id(theCommit));
	helper.putRule("Message", git_commit_message_raw(theCommit));
}

void GitLinkCommit::write(MLINK lnk) const
{
	char buf[GIT_OID_HEXSZ + 1];
	if (valid_)
	{
		MLHelper helper(lnk);
		helper.putGitObject(oid_, repoKey_);
	}
	else
		MLPutSymbol(lnk, "$Failed");
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
		MLPutSymbol(lnk, "$Failed");
}

git_commit* GitLinkCommit::commit()
{
	if (commit_)
		return commit_;
	if (!isValid())
		return NULL;
	if (git_commit_lookup(&commit_, ManagedRepoMap[repoKey_], &oid_) || commit_ == NULL)
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
	GitLinkRepository repo(repoKey_);

	const git_signature* committer = repo.committer();
	if (committer == NULL)
	{
		errCode_ = Message::NoDefaultUserName;
		return false;
	}
	int err = git_branch_create(&ref, repo.repo(), branchName, commit(), force, committer, NULL);
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

git_tree* GitLinkCommit::copyTree()
{
	const git_commit* theCommit = commit();
	if (!isValid() || theCommit == NULL)
		return NULL;
	git_tree* tree;
	git_commit_tree(&tree, theCommit);
	return tree;
}

GitLinkCommitDeque::GitLinkCommitDeque()
	: std::deque<GitLinkCommit>()
	, isValid_(true)
{

}

GitLinkCommitDeque::GitLinkCommitDeque(const GitLinkCommit& commit)
	: std::deque<GitLinkCommit>(1, commit)
	, isValid_(true)
{

}

GitLinkCommitDeque::GitLinkCommitDeque(const GitLinkRepository& repo, MLExpr expr)
	: std::deque<GitLinkCommit>()
	, isValid_(true)
{
	if (expr.isList())
	{
		for (int i = 1; i <= expr.length(); i++)
			push_back(GitLinkCommit(repo, expr.part(i)));
	}
	else if (expr.isString())
	{
		push_back(GitLinkCommit(repo, expr));
	}

	for (GitLinkCommit c : *this)
	{
		c.commit();
		isValid_ = isValid_ && c.isValid();
	}
	if (!isValid_)
		errCode_ = Message::BadCommitish;
}

GitLinkCommitDeque& GitLinkCommitDeque::operator=(const GitLinkCommitDeque& theDeque)
{
	clear();
	for (const GitLinkCommit& c : theDeque)
		push_back(c);
	isValid_ = theDeque.isValid_;
	return *this;
}

const git_commit** GitLinkCommitDeque::commits() const
{
	if (commits_.empty())
	{
		for (const GitLinkCommit& c : *this)
			commits_.push_back(const_cast<GitLinkCommit&>(c).commit());
	}
	return &commits_[0];
}
