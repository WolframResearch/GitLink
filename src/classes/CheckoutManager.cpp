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

bool CheckoutManager::checkoutScanForConflicts(const char* ref)
{
	GitTree headTree(repo_, "HEAD");
	GitTree refTree(repo_, ref);
	RepoStatus status(repo_);

	if (!headTree.isValid() || !refTree.isValid() || !status.isValid())
		return false;

	PathSet refChangedFiles = headTree.getDiffFiles(refTree);

	for (const auto& file : refChangedFiles)
	{
		if (status.fileChanged(file))
			return false;
	}

	return true;
}
