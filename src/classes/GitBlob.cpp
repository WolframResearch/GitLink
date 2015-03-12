/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include <stdlib.h>
#include <unordered_map>

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "GitLinkRepository.h"
#include "GitLinkCommit.h"
#include "GitBlob.h"

#include "Message.h"
#include "MLHelper.h"

GitBlob::GitBlob(const MLExpr& expr)
	: repo_(expr)
{
	MLExpr e = expr;

	if (e.testHead("GitObject") && e.length() == 2 && e.part(1).isString())
		e = e.part(1);
	if (repo_.isValid() && e.isString())
	{
		const char* sha = e.asString();
		if (git_oid_fromstr(&oid_, sha) != 0)
			errCode_ = Message::BadSHA;
		else if (git_blob_lookup(&blob_, repo_.repo(), &oid_) != 0)
			errCode_ = Message::NoBlob;
	}
}

GitBlob::GitBlob(const GitLinkRepository& repo, MLINK lnk, const char* format)
	: repo_(repo.key())
{
	if (!repo.isValid())
		return;
	if (strcmp(format, "UTF8String") == 0 || strcmp(format, "ByteString") == 0)
	{
		bool utf = (strcmp(format, "UTF8String") == 0);
		const unsigned char* bytes;
		int len, unused;
		if (utf)
			MLGetUTF8String(lnk, &bytes, &len, &unused);
		else
			MLGetByteString(lnk, &bytes, &len, 0);

		if (git_blob_create_frombuffer(&oid_, repo.repo(), bytes, len) == 0)
			git_blob_lookup(&blob_, repo.repo(), &oid_);

		if (utf)
			MLReleaseUTF8String(lnk, bytes, len);
		else
			MLReleaseByteString(lnk, bytes, len);
		return;
	}
	errCode_ = Message::BadFormat;
}

GitBlob::~GitBlob()
{
	if (blob_)
		git_blob_free(blob_);
}

void GitBlob::write(MLINK lnk) const
{
	MLHelper helper(lnk);
	if (blob_ != NULL)
		helper.putGitObject(oid_, repo_);
	else
		helper.putSymbol("$Failed");
}

void GitBlob::writeContents(MLINK lnk, const char* format) const
{
	MLHelper helper(lnk);
	if (blob_ == NULL)
		helper.putSymbol("$Failed");
	else if (strcmp(format, "UTF8String") == 0)
		helper.putBlobUTF8String(blob_);
	else if (strcmp(format, "ByteString") == 0)
		helper.putBlobByteString(blob_);
	else
		helper.putSymbol("$Failed");
}

