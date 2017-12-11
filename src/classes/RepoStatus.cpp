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
#include "GitLinkRepository.h"

#include "Message.h"
#include "MLExpr.h"
#include "MLHelper.h"
#include "RepoInterface.h"
#include "RepoStatus.h"
#include "Signature.h"

#if WIN
#include <shlwapi.h>
#include <codecvt>
#endif

RepoStatus::RepoStatus(GitLinkRepository& repo, bool doRenames, bool includeIgnored, bool recurseUntrackedDirs)
	: repo_(repo)
	, isValid_(false)
	, doRenames_(doRenames)
	, includeIgnored_(includeIgnored)
	, recurseUntrackedDirs_(recurseUntrackedDirs)
{
	updateStatus();
}

void RepoStatus::updateStatus()
{
	isValid_ = false;
	indexStatus_.clear();
	workingTreeStatus_.clear();

	if (!repo_.isValid())
	{
		propagateError(repo_);
		return;
	}
	if (git_repository_is_bare(repo_.repo()))
	{
		errCode_ = Message::BareRepo;
		return;
	}

	git_status_options options;
	git_status_init_options(&options, GIT_STATUS_OPTIONS_VERSION);

	options.show = GIT_STATUS_SHOW_INDEX_ONLY;
	options.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED | GIT_STATUS_OPT_EXCLUDE_SUBMODULES | GIT_STATUS_OPT_UPDATE_INDEX;
	if (doRenames_)
		options.flags |= GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX |
						GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR |
						GIT_STATUS_OPT_RENAMES_FROM_REWRITES;
	if (includeIgnored_)
		options.flags |= GIT_STATUS_OPT_INCLUDE_IGNORED;
	if (recurseUntrackedDirs_)
		options.flags |= GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS;

	if (git_status_foreach_ext(repo_.repo(), &options, RepoStatus::statusCallback_, (void *)&indexStatus_))
	{
		errCode_ = Message::NoIndex;
		return;
	}

	options.show = GIT_STATUS_SHOW_WORKDIR_ONLY;
	if (git_status_foreach_ext(repo_.repo(), &options, RepoStatus::statusCallback_, (void*)&workingTreeStatus_))
	{
		errCode_ = Message::NoWorkingTree;
		return;
	}
	isValid_ = true;
}

void RepoStatus::writeStatus(MLINK lnk)
{
	MLHelper helper(lnk);
	helper.beginFunction("Association");

	writeFiles_(helper, "New", GIT_STATUS_WT_NEW);
	writeFiles_(helper, "Modified", GIT_STATUS_WT_MODIFIED);
	writeFiles_(helper, "Deleted", GIT_STATUS_WT_DELETED);
	if (doRenames_)
		writeFiles_(helper, "Renamed", GIT_STATUS_WT_RENAMED);
	writeFiles_(helper, "TypeChange", GIT_STATUS_WT_TYPECHANGE);
	if (includeIgnored_)
		writeFiles_(helper, "Ignored", GIT_STATUS_IGNORED);
	writeFiles_(helper, "IndexNew", GIT_STATUS_INDEX_NEW);
	writeFiles_(helper, "IndexModified", GIT_STATUS_INDEX_MODIFIED);
	writeFiles_(helper, "IndexDeleted", GIT_STATUS_INDEX_DELETED);
	if (doRenames_)
		writeFiles_(helper, "IndexRenamed", GIT_STATUS_INDEX_RENAMED);
	writeFiles_(helper, "IndexTypeChange", GIT_STATUS_INDEX_TYPECHANGE);

	helper.endFunction();
}

void RepoStatus::convertFileNamesToLower(WolframLibraryData libData)
{
	// Implementation is a bit wasteful with time and memory, but the results of
	// RepoStatus are often small, so I'm valuing the compact code more here.
	FileStatusMap tmp;

	for (const auto& entry : indexStatus_)
		tmp.insert({MLToLower(libData, entry.first), entry.second});
	indexStatus_ = tmp;
	tmp.clear();

	for (const auto& entry : workingTreeStatus_)
		tmp.insert({MLToLower(libData, entry.first), entry.second});
	workingTreeStatus_ = tmp;
}

FileNameSet RepoStatus::allFileNames()
{
	FileNameSet fileSet;
	std::string str;

	for (const auto& it : indexStatus_)
	{
		str = it.first;
		fileSet.insert(str);
	}
	for (const auto& it : workingTreeStatus_)
	{
		str = it.first;
		fileSet.insert(str);
	}

	return fileSet;
}

bool RepoStatus::fileChanged(const std::string& filePath)
{
	if (indexStatus_.count(filePath))
		return true;
	if (workingTreeStatus_.count(filePath))
		return true;
	return false;
}

void RepoStatus::writeFiles_(MLHelper& helper, const char* keyName, git_status_t status)
{
	FileStatusMap& statusList = workingTreeStatus_;
	if (status == GIT_STATUS_INDEX_NEW ||
		status == GIT_STATUS_INDEX_MODIFIED ||
		status == GIT_STATUS_INDEX_DELETED ||
		status == GIT_STATUS_INDEX_RENAMED ||
		status == GIT_STATUS_INDEX_TYPECHANGE)
	{
		statusList = indexStatus_;
	}

	helper.putRule(keyName);
	helper.beginList();

	for (auto& entry : statusList)
	{
		if ((entry.second & status) != 0)
			helper.putString(PathString(entry.first));
	}

	helper.endList();
}

int RepoStatus::statusCallback_(const char* path, unsigned int status_flags, void* payload)
{
	FileStatusMap* statusList = (FileStatusMap*) payload;
	statusList->insert({path, status_flags});
	return 0;
}

std::deque<std::string> FileNameSet::getPathSpecMatches(const PathString& spec)
{
	std::deque<std::string> matches;
	const char* specCstr = spec.git().c_str();
	const git_strarray specArray { const_cast<char**>(&specCstr), 1 };
	git_pathspec* pathspec;

	git_pathspec_new(&pathspec, &specArray);

	for (const auto& it : *this)
		if (git_pathspec_matches_path(pathspec, 0, it.c_str()))
			matches.push_back(it);

	git_pathspec_free(pathspec);
	return matches;
}
