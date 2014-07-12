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
#include "RepoInterface.h"
#include "GitLinkRepository.h"
#include "Message.h"

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


// typedef enum {
// 	GIT_REPOSITORY_STATE_NONE,
// 	GIT_REPOSITORY_STATE_MERGE,
// 	GIT_REPOSITORY_STATE_REVERT,
// 	GIT_REPOSITORY_STATE_CHERRY_PICK,
// 	GIT_REPOSITORY_STATE_BISECT,
// 	GIT_REPOSITORY_STATE_REBASE,
// 	GIT_REPOSITORY_STATE_REBASE_INTERACTIVE,
// 	GIT_REPOSITORY_STATE_REBASE_MERGE,
// 	GIT_REPOSITORY_STATE_APPLY_MAILBOX,
// 	GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE,
// } git_repository_state_t;

void GitLinkRepository::writeProperties(MLINK lnk)
{
	if (isValid())
	{
		MLPutFunction(lnk, "Association", 7);
		putRule_(lnk, "ShallowQ", git_repository_is_shallow(repo_));
		putRule_(lnk, "BareQ", git_repository_is_bare(repo_));
		putRule_(lnk, "DetachedHeadQ", git_repository_head_detached(repo_));
		putRule_(lnk, "GitDirectory", git_repository_path(repo_));
		putRule_(lnk, "WorkingDirectory", git_repository_workdir(repo_));
		putRule_(lnk, "Namespace", git_repository_get_namespace(repo_));
		putRule_(lnk, "State", (git_repository_state_t) git_repository_state(repo_));
	}
	else
		MLPutSymbol(lnk, "$Failed");
}

void GitLinkRepository::putRule_(MLINK lnk, const char* key, int value)
{
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);
	MLPutSymbol(lnk, value ? "True" : "False");
}

void GitLinkRepository::putRule_(MLINK lnk, const char* key, const char* value)
{
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);
	if (value == NULL)
		MLPutSymbol(lnk, "$Failed");
	else
		MLPutUTF8String(lnk, (const unsigned char*)value, (int)strlen(value));
}

void GitLinkRepository::putRule_(MLINK lnk, const char* key, git_repository_state_t value)
{
	MLPutFunction(lnk, "Rule", 2);
	MLPutString(lnk, key);

	const char* state;
	switch (value)
	{
		case GIT_REPOSITORY_STATE_MERGE:
			state = "Merge";
			break;
		case GIT_REPOSITORY_STATE_REVERT:
			state = "Revert";
			break;
		case GIT_REPOSITORY_STATE_CHERRY_PICK:
			state = "CherryPick";
			break;
		case GIT_REPOSITORY_STATE_BISECT:
			state = "Bisect";
			break;
		case GIT_REPOSITORY_STATE_REBASE:
			state = "Rebase";
			break;
		case GIT_REPOSITORY_STATE_REBASE_INTERACTIVE:
			state = "RebaseInteractive";
			break;
		case GIT_REPOSITORY_STATE_REBASE_MERGE:
			state = "RebaseMerge";
			break;
		case GIT_REPOSITORY_STATE_APPLY_MAILBOX:
			state = "ApplyMailbox";
			break;
		case GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE:
			state = "ApplyMailboxOrRebase";
			break;
		default:
			state = "None";
			break;
	}
	MLPutString(lnk, state);
}

