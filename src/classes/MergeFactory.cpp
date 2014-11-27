/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "MergeFactory.h"

#include "GitLinkRepository.h"
#include "Message.h"

bool MergeFactory::initialize(MergeFactoryMergeType mergeType)
{
	if (!repo_.isValid())
		return false;

	if (argv_.length() < 3)
		return false;

	// Arg2: Merge heads
	if (argv_.part(2).isList())
	{
		for (int i = 1; i < argv_.partLength(2); i++)
			mergeSources_.push_back(GitLinkCommit(repo_, argv_.part(2, i)));
	}
	else if (argv_.part(2).isString())
	{
		mergeSources_.push_back(GitLinkCommit(repo_, argv_.part(2)));
	}
	bool validMergeSources = !mergeSources_.empty();
	for (const GitLinkCommit& c : mergeSources_)
		validMergeSources = validMergeSources && c.isValid();
	if (!validMergeSources)
	{
		errCode_ = Message::InvalidSource;
		return false;
	}

	// Arg3: Destination reference
	if (argv_.part(3).isString())
		dest_ = new GitLinkCommit(repo_, argv_.part(3));
	if (!dest_->isValid())
	{
		errCode_ = Message::InvalidDest;
		return false;
	}

	// Arg4: Commit message
	if (argv_.part(4).isString())
		commitMessage_ = argv_.part(4).asString();

	// Arg5: Callbacks
	if (argv_.part(5).isList() && argv_.part(5).length() == 3)
	{
		conflictFunctions_ = argv_.part(5).part(1);
		finalFunctions_ = argv_.part(5).part(2);
		progressFunction_ = argv_.part(5).part(3);
	}
	else
	{
		errCode_ = Message::InvalidCallbacks;
		return false;
	}

	// Args 6, 7, 8: AllowCommit, AllowFastForward, AllowIndexChanges
	allowCommit_ = argv_.part(6).testSymbol("True");
	allowFastForward_ = argv_.part(6).testSymbol("True");
	allowIndexChanges_ = argv_.part(6).testSymbol("True");

	return true;
}

void MergeFactory::mlHandleError(WolframLibraryData libData, const char* functionName) const
{
	if (!repo_.isValid())
	{
		repo_.mlHandleError(libData, functionName);
		return;
	}
	MLHandleError(libData, functionName, errCode_, errCodeParam_);
};

void MergeFactory::writeSHAOrFailure(MLINK lnk)
{
	MLPutString(lnk, "dummy");
}

void MergeFactory::doMerge()
{

}
