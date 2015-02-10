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
#include "RepoStatus.h"

#include "Message.h"
#include "MLExpr.h"
#include "MLHelper.h"
#include "RepoStatus.h"

CheckoutManager::CheckoutManager(GitLinkRepository& repo)
	: repo_(repo)
{

}

bool CheckoutManager::initCheckout(WolframLibraryData libData, const char* ref)
{
	refChangedFiles_.clear();
	ref_ = "";

	if (!repo_.isValid())
	{
		propagateError(repo_);
		return false;
	}

	GitTree headTree(repo_, "HEAD");
	GitTree refTree(repo_, ref);
	RepoStatus status(repo_, false);

#if MAC || WIN // case-insensitive file systems
	status.convertFileNamesToLower(libData);
#endif // MAC || WIN

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

	refChangedFiles_ = headTree.getDiffPaths(refTree);
	ref_ = ref;

	for (const auto& file : refChangedFiles_)
	{
		std::string decasedfile = file;
#if MAC || WIN // case-insensitive file systems
		decasedfile = MLToLower(libData, decasedfile);
#endif // MAC || WIN
		if (status.fileChanged(decasedfile))
		{
			errCode_ = Message::CheckoutConflict;
			return false;
		}
	}

	return true;
}

bool CheckoutManager::doCheckout()
{
	bool result = repo_.setHead(ref_.c_str());
	if (!result)
	{
		propagateError(repo_);
		return false;
	}

	git_checkout_options options;
	git_checkout_init_options(&options, GIT_CHECKOUT_OPTIONS_VERSION);

	options.checkout_strategy = GIT_CHECKOUT_FORCE | GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH;
	populatePaths_(&options.paths);

	if (git_checkout_head(repo_.repo(), &options))
	{
		freePaths_(&options.paths);
		errCode_ = Message::CheckoutFailed;
		errCodeParam_ = strdup(giterr_last()->message);
		return false;
	}

	freePaths_(&options.paths);
	return true;
}

void CheckoutManager::populatePaths_(git_strarray* strarray) const
{
	strarray->strings = (char **) malloc (sizeof(char *) * refChangedFiles_.size());
	strarray->count = refChangedFiles_.size();

	int i = 0;
	for (const auto& file : refChangedFiles_)
		strarray->strings[i++] = (char*) file.c_str();
}

void CheckoutManager::freePaths_(git_strarray* strarray) const
{
	if (strarray->count > 0)
	{
		free((void*)strarray->strings);
		strarray->count = 0;
	}
}
