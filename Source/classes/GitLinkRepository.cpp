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

#include "Message.h"
#include "MLHelper.h"
#include "RepoInterface.h"

GitLinkRepository::GitLinkRepository(WolframLibraryData libData, mint Argc, MArgument* Argv, int repoArg) :
	key_(BAD_KEY), repo_(NULL), remoteName_(NULL), remote_(NULL)
{
	if (Argc > repoArg)
	{
		char* repoPath = MArgument_getUTF8String(Argv[repoArg]);
		if (repoPath != NULL)
		{
			if (git_repository_open(&repo_, repoPath) != 0)
			{
				git_repository_free(repo_);
				repo_ = NULL;
			}
			libData->UTF8String_disown(repoPath);
		}
	}
}

GitLinkRepository::GitLinkRepository(MLINK lnk) :
	key_(BAD_KEY), repo_(NULL), remoteName_(NULL), remote_(NULL)
{
	switch (MLGetType(lnk))
	{
		case MLTKINT:
			MLGetInteger64(lnk, &key_);
			repo_ = ManagedRepoMap[key_];
			break;

		case MLTKSTR:
		{
			const unsigned char* str;
			int numBytes;
			MLGetUTF8String(lnk, &str, &numBytes, NULL);
			if (git_repository_open(&repo_, (char*) str) != 0)
			{
				git_repository_free(repo_);
				repo_ = NULL;
			}
			MLReleaseUTF8String(lnk, str, numBytes);
			break;
		}
		default:
			break;
	}
}

GitLinkRepository::GitLinkRepository(mint key) :
	key_(key), repo_(ManagedRepoMap[key]), remoteName_(NULL), remote_(NULL)
{
}


GitLinkRepository::~GitLinkRepository()
{
	if (remote_)
		git_remote_free(remote_);
	if (key_ == BAD_KEY && repo_ != NULL)
		git_repository_free(repo_);
}

void GitLinkRepository::setKey(mint key)
{
	key_ = key;
	ManagedRepoMap[key] = repo_;
}

void GitLinkRepository::unsetKey()
{
	ManagedRepoMap.erase(key_);
	key_ = BAD_KEY;
}

bool GitLinkRepository::setRemote_(const char* remoteName)
{
	// one-level cache
	if (remoteName_ != NULL && strcmp(remoteName, remoteName_) == 0 && remote_)
		return true;

	if (remote_)
		git_remote_free(remote_);
	if (remoteName_)
		free((void*)remoteName_);
	remoteName_ = NULL;

	if (git_remote_load(&remote_, repo_, remoteName))
	{
		git_remote_free(remote_);
		remote_ = NULL;
		return false;
	}

	remoteName_ = (char*) malloc(strlen(remoteName) + 1);
	strcpy(remoteName_, remoteName);
	return true;
}

const char* GitLinkRepository::fetch(const char* remoteName, bool prune)
{
	if (!isValid())
		return Message::BadRepo;
	if (!setRemote_(remoteName))
		return Message::BadRemote;

	git_signature* sig;
	if (git_signature_default(&sig, repo_))
		return Message::BadConfiguration;

	const char* returnValue = Message::Success;
	
	if (git_remote_connect(remote_, GIT_DIRECTION_FETCH))
		returnValue = Message::RemoteConnectionFailed;
	else if (git_remote_download(remote_))
		returnValue = Message::DownloadFailed;
	else if (git_remote_update_tips(remote_, sig, "Wolfram gitlink: fetch"))
		returnValue = Message::UpdateTipsFailed;

	git_remote_disconnect(remote_);

//	if (git_remote_fetch(remote_, sig, "Wolfram gitLink: fetch"))
//		returnValue = Message::FetchFailed;

	git_signature_free(sig);
	return returnValue;
}

const char* GitLinkRepository::push(const char* remoteName, const char* branchName)
{
	return NULL;
}


void GitLinkRepository::writeProperties(MLINK lnk)
{
	if (isValid())
	{
		MLHelper helper(lnk);
		helper.beginFunction("Association");
		helper.putRule("ShallowQ", git_repository_is_shallow(repo_));
		helper.putRule("BareQ", git_repository_is_bare(repo_));
		helper.putRule("DetachedHeadQ", git_repository_head_detached(repo_));
		helper.putRule("GitDirectory", git_repository_path(repo_));
		helper.putRule("WorkingDirectory", git_repository_workdir(repo_));
		helper.putRule("Namespace", git_repository_get_namespace(repo_));
		helper.putRule("State", (git_repository_state_t) git_repository_state(repo_));

		helper.putRule("Conflicts");
		writeConflictList_(helper);

		helper.putRule("Remotes");
		writeRemoteList_(helper);

		helper.putRule("LocalBranches");
		writeBranchList_(helper, GIT_BRANCH_LOCAL);

		helper.putRule("RemoteBranches");
		writeBranchList_(helper, GIT_BRANCH_REMOTE);
	}
	else
		MLPutSymbol(lnk, "$Failed");
}

void GitLinkRepository::writeConflictList_(MLHelper& helper)
{
	git_index* index;
	git_index_conflict_iterator* it;
	const git_index_entry* ancestor;
	const git_index_entry* ours;
	const git_index_entry* theirs;

	git_repository_index(&index, repo_);
	git_index_conflict_iterator_new(&it, index);

	helper.beginList();
	while (!git_index_conflict_next(&ancestor, &ours, &theirs, it))
		helper.putString(ancestor->path);
	helper.endList();

	git_index_conflict_iterator_free(it);
	git_index_free(index);
}

void GitLinkRepository::writeRemoteList_(MLHelper& helper)
{
	git_strarray remotesList;
	helper.beginList();
	if (!git_remote_list(&remotesList, repo_))
	{
		for (int i = 0; i < remotesList.count; i++)
			helper.putString(remotesList.strings[i]);
		git_strarray_free(&remotesList);
	}
	helper.endList();
}

void GitLinkRepository::writeBranchList_(MLHelper& helper, git_branch_t flag)
{
	git_branch_iterator* it;
	git_reference* ref;
	git_branch_t refType;

	helper.beginList();
	git_branch_iterator_new(&it, repo_, flag);
	while (!git_branch_next(&ref, &refType, it))
	{
		const char* branchName;
		git_branch_name(&branchName, ref);
		helper.putString(branchName);
		git_reference_free(ref);
	}
	helper.endList();
	git_branch_iterator_free(it);
}

void GitLinkRepository::writeStatus(MLINK lnk)
{
	git_status_list* statusList;
	git_status_options opts;

	git_status_init_options(&opts, GIT_STATUS_OPTIONS_VERSION);
	opts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED | GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS | GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX;
	if (isValid() && !git_status_list_new(&statusList, repo_, &opts))
	{
		MLHelper helper(lnk);

		helper.beginFunction("Association");

		helper.putRule("Untracked", statusList, GIT_STATUS_WT_NEW);
		helper.putRule("Modified", statusList, GIT_STATUS_WT_MODIFIED);
		helper.putRule("Deleted", statusList, GIT_STATUS_WT_DELETED);
		helper.putRule("TypeChange", statusList, GIT_STATUS_WT_TYPECHANGE);

		helper.putRule("IndexNew", statusList, GIT_STATUS_INDEX_NEW);
		helper.putRule("IndexModified", statusList, GIT_STATUS_INDEX_MODIFIED);
		helper.putRule("IndexDeleted", statusList, GIT_STATUS_INDEX_DELETED);
		helper.putRule("IndexTypeChange", statusList, GIT_STATUS_INDEX_TYPECHANGE);
		helper.putRule("IndexRenamed", statusList, GIT_STATUS_INDEX_RENAMED);
		
		git_status_list_free(statusList);
	}
	else
		MLPutSymbol(lnk, "$Failed");
}
