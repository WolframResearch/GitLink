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


GitLinkCommit::GitLinkCommit(const GitLinkRepository& repo, MLINK link) :
	repo_(repo), valid_(false), notSpec_(false), commit_(NULL), errCode_(NULL)
{
	MLMARK mlmark = MLCreateMark(link);
	const char* mlOwnedString = NULL;
	bool done = false;
	int mlStringLen = 0;
	int argCount;
	int unused;

	while (repo.isValid() && !done)
	{
		switch (MLGetType(link))
		{
			case MLTKFUNC:
				MLGetUTF8Function(link, (const unsigned char**)&mlOwnedString, &mlStringLen, &argCount);
				if (strcmp(mlOwnedString, "Not") == 0 && argCount == 1)
					notSpec_ = !notSpec_;
				else
					done = true;
				break;

			case MLTKSTR:
			{
				git_object* obj;
				MLGetUTF8String(link, (const unsigned char **)&mlOwnedString, &mlStringLen, &unused);
				if (git_revparse_single(&obj, repo_.repo(), mlOwnedString) == 0)
				{
					if (git_object_type(obj) == GIT_OBJ_COMMIT)
					{
						valid_ = true;
						git_oid_cpy(&oid_, git_object_id(obj));
					}
				}
				done = true;
				break;
			}

			default:
				done = true;
				break;
		}
		if (mlOwnedString)
			MLReleaseUTF8String(link, (const unsigned char*)mlOwnedString, mlStringLen);
		mlOwnedString = NULL;
	}

	MLClearError(link);
	MLSeekToMark(link, mlmark, 0);
	MLDestroyMark(link, mlmark);
	MLTransferExpression(NULL, link);
}

GitLinkCommit::GitLinkCommit(const GitLinkRepository& repo, git_index* index, GitLinkCommit& parent,
								const git_signature* author, const char* message) :
	repo_(repo), valid_(false), notSpec_(false), commit_(NULL), errCode_(NULL)
{
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
	else
	{
		git_oid treeId;
		if (author == NULL)
			author = repo.committer();

		if (!git_index_write_tree_to(&treeId, index, repo.repo()))
		{
			git_tree* newTree;
			const git_commit* parentCommit = parent.commit();
			git_tree_lookup(&newTree, repo.repo(), &treeId);
			if (!git_commit_create(&oid_, repo.repo(), NULL, author, repo.committer(), NULL, message, newTree, 1, &parentCommit))
				valid_ = true;
			else
				errCode_ = Message::GitCommitError;
		}
		else
			errCode_ = Message::CantWriteTree;
	}
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

int GitLinkCommit::parentCount()
{
	const git_commit* theCommit = commit();

	if (!isValid() || theCommit == NULL)
		return 0;
	return git_commit_parentcount(theCommit);
}

void GitLinkCommit::mlWriteMessagePacket(WolframLibraryData libData, MLINK lnk, const char* functionName)
{
	if (errCode_ == NULL)
		return;

	MLPutFunction(lnk, "EvaluatePacket", 1);
	MLPutFunction(lnk, "Message", 1);
	MLPutFunction(lnk, "MessageName", 2);
	MLPutSymbol(lnk, functionName);
	MLPutString(lnk, errCode_);
	libData->processWSLINK(lnk);
	int pkt = MLNextPacket(lnk);
	if ( pkt == RETURNPKT)
		MLNewPacket(lnk);
}
