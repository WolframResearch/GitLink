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

#include "CheckoutManager.h"
#include "GitLinkCommit.h"
#include "GitTree.h"
#include "RepoStatus.h"

#include "Message.h"
#include "MLExpr.h"
#include "MLHelper.h"
#include "RepoStatus.h"

CheckoutManager::CheckoutManager(GitLinkRepository& repo)
	: repo_(repo)
{

}

bool CheckoutManager::initCheckout(const char* ref)
{
	if (!repo_.isValid())
	{
		propagateError(repo_);
		return false;
	}

	GitTree headTree(repo_, "HEAD");
	GitTree refTree(repo_, ref);
	RepoStatus status(repo_, false);

	if (!headTree.isValid())
	{
		propagateError(headTree);
		return false;
	}
	if (!refTree.isValid())
	{
		propagateError(refTree);
		return false;
	}
	if (!status.isValid())
	{
		propagateError(status);
		return false;
	}

	PathSet refChangedFiles = headTree.getDiffFiles(refTree);

	for (const auto& file : refChangedFiles)
	{
		if (status.fileChanged(file))
		{
			errCode_ = Message::CheckoutConflict;
			return false;
		}
	}

	return true;
}

void CheckoutManager::doCheckout()
{

}
