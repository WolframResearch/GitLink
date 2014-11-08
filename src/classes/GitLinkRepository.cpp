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

#include <locale>

#if WIN
#include <shlwapi.h>
#include <codecvt>
#endif

GitLinkRepository::GitLinkRepository(MLINK lnk)
	: key_(BAD_KEY)
	, repo_(NULL)
	, remoteName_(NULL)
	, committer_(NULL)
	, remote_(NULL)
	, connector_(NULL)
{
	switch (MLGetType(lnk))
	{
		case MLTKINT:
			MLGetMint(lnk, &key_);
			repo_ = ManagedRepoMap[key_];
			break;

		case MLTKSTR:
		{
			std::string repoPath = MLGetCPPString(lnk);
			if (!repoPath.empty())
			{
				if (git_repository_open(&repo_, repoPath.c_str()) != 0)
				{
					git_repository_free(repo_);
					repo_ = NULL;
				}
			}
			break;
		}
		default:
			break;
	}
}

GitLinkRepository::GitLinkRepository(mint key)
	: key_(key)
	, repo_(ManagedRepoMap[key])
	, committer_(NULL)
	, remoteName_(NULL)
	, remote_(NULL)
	, connector_(NULL)
{
}

GitLinkRepository::GitLinkRepository(git_repository* repo, WolframLibraryData libData)
	: key_(BAD_KEY)
	, repo_(repo)
	, committer_(NULL)
	, remoteName_(NULL)
	, remote_(NULL)
	, connector_(NULL)
{
	MLINK lnk = libData->getMathLink(libData);

	MLPutFunction(lnk, "EvaluatePacket", 1);
	MLPutFunction(lnk, "CreateManagedLibraryExpression", 2);
	MLPutString(lnk, "gitRepo");
	MLPutSymbol(lnk, "GitRepo");

	libData->processWSLINK(lnk);
	while (MLNextPacket(lnk) != RETURNPKT)
		MLNewPacket(lnk);

	MLExpr repoExpr(lnk);
	mint repoId = repoExpr.part(1).getInt();
	if (repoId > 0)
		setKey(repoId);
	else
		errCode_ = Message::DisassociatedRepo;
}


GitLinkRepository::~GitLinkRepository()
{
	if (remote_)
		git_remote_free(remote_);
	if (key_ == BAD_KEY && repo_ != NULL)
		git_repository_free(repo_);
	if (committer_)
		git_signature_free(committer_);
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

const git_signature* GitLinkRepository::committer() const
{
	if (repo_ == NULL)
		return NULL;
	if (committer_)
		git_signature_free(committer_);

	// recreating the signature every time assures correct commit times
	// and deals with the very rare cases where the repo's default committer changes
	git_signature_default(&committer_, repo_);
	return committer_;
}

bool GitLinkRepository::setRemote_(const char* remoteName, const char* privateKeyFile)
{
	// one-level cache
	if (remote_ && remoteName_ && (strcmp(remoteName, remoteName_) == 0))
	{
		if (!privateKeyFile && !connector_.keyFile())
			return true;
		if (privateKeyFile && connector_.keyFile() && (strcmp(privateKeyFile, connector_.keyFile()) == 0))
			return true;
	}

	if (remote_)
		git_remote_free(remote_);
	free((void*)remoteName_);

	remoteName_ = strdup(remoteName);
	connector_ = RemoteConnector(privateKeyFile);

	if (git_remote_load(&remote_, repo_, remoteName))
	{
		remote_ = NULL;
		return false;
	}

	return true;
}

bool GitLinkRepository::fetch(const char* remoteName, const char* privateKeyFile, bool prune)
{
	errCode_ = errCodeParam_ = NULL;
	giterr_clear();

	if (!isValid())
		errCode_ = Message::BadRepo;
	else if (!setRemote_(remoteName, privateKeyFile))
		errCode_ = Message::BadRemote;
	else if (!connector_.fetch(remote_))
	{
		errCode_ = Message::RemoteConnectionFailed;
		errCodeParam_ = giterr_last() ? giterr_last()->message : NULL;
	}
	if (errCode_)
		return false;
	
	if (git_remote_download(remote_))
	{
		errCode_ = Message::DownloadFailed;
		errCodeParam_ = giterr_last()->message;
	}
	else if (git_remote_update_tips(remote_, committer(), "Wolfram gitlink: fetch"))
	{
		errCode_ = Message::UpdateTipsFailed;
		errCodeParam_ = giterr_last()->message;
	}

	git_remote_disconnect(remote_);

	return (errCode_ == NULL);
}

int GitLinkRepository::pushCallBack_(const char* ref, const char* msg, void* data)
{
	if (msg)
	{
		GitLinkRepository* repo = static_cast<GitLinkRepository*>(data);
		repo->errCode_ = Message::RefNotPushed;
		repo->errCodeParam_ = giterr_last()->message;
		return 1;
	}
	return 0;
}

static int packbuilder_progress(int stage, unsigned int current, unsigned int total, void* payload)
{
	char x[255];
	sprintf(x, "pack builder (%d): %d/%d", stage, current, total);

	WolframLibraryData libData = (WolframLibraryData) payload;
	MLINK lnk = libData->getMathLink(libData);
	MLPutFunction(lnk, "EvaluatePacket", 1);
	MLPutFunction(lnk, "PrintTemporary", 1);
	MLPutString(lnk, x);
	libData->processWSLINK(lnk);
	int pkt = MLNextPacket(lnk);
	if ( pkt == RETURNPKT)
		MLNewPacket(lnk);
	return 0;
}

static int transfer_progress(unsigned int current, unsigned int total, size_t bytes, void* payload)
{
	char x[255];
	sprintf(x, "transfer: %d/%d, %d bytes", current, total, (int) bytes);

	WolframLibraryData libData = (WolframLibraryData) payload;
	MLINK lnk = libData->getMathLink(libData);
	MLPutFunction(lnk, "EvaluatePacket", 1);
	MLPutFunction(lnk, "Print", 1);
	MLPutString(lnk, x);
	libData->processWSLINK(lnk);
	int pkt = MLNextPacket(lnk);
	if ( pkt == RETURNPKT)
		MLNewPacket(lnk);
	return 0;
}

bool GitLinkRepository::push(MLINK lnk, const char* remoteName, const char* privateKeyFile, const char* branchName)
{
	errCode_ = errCodeParam_ = NULL;
	if (!isValid())
		errCode_ = Message::BadRepo;
	else if (!setRemote_(remoteName, privateKeyFile))
		errCode_ = Message::BadRemote;
	else if (!connector_.push(remote_))
	{
		errCode_ = Message::RemoteConnectionFailed;
	}

	if (errCode_)
		return false;

	git_push* pushObject = NULL;
	if (git_push_new(&pushObject, remote_) != 0)
		errCode_ = Message::BadPush;
	else if (git_push_add_refspec(pushObject, branchName) != 0)
		errCode_ = Message::BadCommitish;
	else if (git_push_finish(pushObject) != 0)
	{
		errCode_ = Message::PushUnfinished;
		errCodeParam_ = giterr_last()->message;
	}
	else if (!git_push_unpack_ok(pushObject))
		errCode_ = Message::RemoteUnpackFailed;
	else if (!errCode_)
		git_push_status_foreach(pushObject, pushCallBack_, &errCode_);

	if (pushObject)
		git_push_free(pushObject);

	git_remote_disconnect(remote_);

	return (errCode_ == NULL);
}


void GitLinkRepository::writeProperties(MLINK lnk) const
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

void GitLinkRepository::writeConflictList_(MLHelper& helper) const
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

void GitLinkRepository::writeRemoteList_(MLHelper& helper) const
{
	git_strarray remotesList;
	helper.beginFunction("Association");
	if (!git_remote_list(&remotesList, repo_))
	{
		for (int i = 0; i < remotesList.count; i++)
		{
			git_remote* remote;
			git_strarray refspecs;
			if (git_remote_load(&remote, repo_, remotesList.strings[i]) != 0)
				continue;

			helper.putRule(remotesList.strings[i]);

			helper.beginFunction("Association");
			helper.putRule("FetchURL", git_remote_url(remote));
			helper.putRule("PushURL",
				(git_remote_pushurl(remote) == NULL) ?
					git_remote_url(remote) : git_remote_pushurl(remote));
			helper.putRule("FetchRefSpecs");
			helper.beginList();
			if (git_remote_get_fetch_refspecs(&refspecs, remote) == 0)
			{
				for (int j = 0; j < refspecs.count; j++)
					helper.putString(refspecs.strings[j]);
				git_strarray_free(&refspecs);
			}
			helper.endList();
			helper.putRule("PushRefSpecs");
			helper.beginList();
			if (git_remote_get_push_refspecs(&refspecs, remote) == 0)
			{
				for (int j = 0; j < refspecs.count; j++)
					helper.putString(refspecs.strings[j]);
				git_strarray_free(&refspecs);
			}
			helper.endList();
			helper.endFunction();

			git_remote_free(remote);
		}
		git_strarray_free(&remotesList);
	}
	helper.endFunction();
}

void GitLinkRepository::writeBranchList_(MLHelper& helper, git_branch_t flag) const
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

void GitLinkRepository::writeStatus(MLINK lnk) const
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
