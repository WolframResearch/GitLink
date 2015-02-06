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

RepoStatus::RepoStatus(GitLinkRepository& repo)
	: repo_(repo)
	, isValid_(false)
{
	updateStatus();
}

void RepoStatus::updateStatus()
{
	isValid_ = false;
	indexStatus_.clear();
	workingTreeStatus_.clear();

	if (!repo_.isValid() || git_repository_is_bare(repo_.repo()))
		return;

	git_status_options options;
	git_status_init_options(&options, GIT_STATUS_OPTIONS_VERSION);

	options.show = GIT_STATUS_SHOW_INDEX_ONLY;
	options.flags = GIT_STATUS_OPT_DEFAULTS | GIT_STATUS_OPT_EXCLUDE_SUBMODULES;

	if (git_status_foreach_ext(repo_.repo(), &options, RepoStatus::statusCallback_, (void *)&indexStatus_))
		return;

	options.show = GIT_STATUS_SHOW_WORKDIR_ONLY;
	if (git_status_foreach_ext(repo_.repo(), &options, RepoStatus::statusCallback_, (void*)&workingTreeStatus_))
		return;
	isValid_ = true;
}

void RepoStatus::writeStatus(MLINK lnk)
{
	MLHelper helper(lnk);
	helper.beginFunction("Association");

	writeFiles_(helper, "New", GIT_STATUS_WT_NEW);
	writeFiles_(helper, "Modified", GIT_STATUS_WT_MODIFIED);
	writeFiles_(helper, "Deleted", GIT_STATUS_WT_DELETED);
	writeFiles_(helper, "Renamed", GIT_STATUS_WT_RENAMED);
	writeFiles_(helper, "TypeChange", GIT_STATUS_WT_TYPECHANGE);
	writeFiles_(helper, "IndexNew", GIT_STATUS_INDEX_NEW);
	writeFiles_(helper, "IndexModified", GIT_STATUS_INDEX_MODIFIED);
	writeFiles_(helper, "IndexDeleted", GIT_STATUS_INDEX_DELETED);
	writeFiles_(helper, "IndexRenamed", GIT_STATUS_INDEX_RENAMED);
	writeFiles_(helper, "IndexTypeChange", GIT_STATUS_INDEX_TYPECHANGE);

	helper.endFunction();
}

bool RepoStatus::fileChanged(const std::string& filePath)
{
	if (indexStatus_.count(filePath))
		return false;
	if (workingTreeStatus_.count(filePath))
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

	for (auto entry : statusList)
	{
		if ((entry.second & status) != 0)
			helper.putString(entry.first);
	}

	helper.endList();
}

int RepoStatus::statusCallback_(const char* path, unsigned int status_flags, void* payload)
{
	FileStatusMap* statusList = (FileStatusMap*) payload;
	statusList->insert({path, status_flags});
	return 0;
}
