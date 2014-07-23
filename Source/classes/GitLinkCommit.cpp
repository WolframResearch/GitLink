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
	repo_(repo), valid_(false), notSpec_(false)
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

void GitLinkCommit::writeProperties(MLINK lnk) const
{
	MLHelper helper(lnk);
	git_commit* commit;

	if (!isValid())
	{
		helper.putString(Message::BadCommitish);
		return;
	}
	git_commit_lookup(&commit, repo_.repo(), &oid_);

	helper.beginFunction("Association");

	helper.putRule("Parents");
	helper.beginList();
	for (int i = 0; i < git_commit_parentcount(commit); i++)
		helper.putOid(*git_commit_parent_id(commit, i));
	helper.endList();

	helper.putRule("Tree", *git_commit_tree_id(commit));
	helper.putRule("AuthorName", git_commit_author(commit)->name);
	helper.putRule("AuthorEmail", git_commit_author(commit)->email);
	helper.putRule("AuthorTime", git_commit_author(commit)->when);
	helper.putRule("AuthorTimeZone", (double) git_commit_author(commit)->when.offset / 60.);
	helper.putRule("CommitterName", git_commit_committer(commit)->name);
	helper.putRule("CommitterEmail", git_commit_committer(commit)->email);
	helper.putRule("CommitterTime", git_commit_committer(commit)->when);
	helper.putRule("CommitterTimeZone", (double) git_commit_committer(commit)->when.offset / 60.);
	helper.putRule("SHA", *git_commit_id(commit));
	helper.putRule("Message", git_commit_message_raw(commit));
	helper.putRule("Summary", git_commit_summary(commit));

	git_commit_free(commit);
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
