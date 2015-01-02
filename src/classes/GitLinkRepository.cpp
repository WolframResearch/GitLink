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
#include "Signature.h"

#if WIN
#include <shlwapi.h>
#include <codecvt>
#endif

GitLinkRepository::GitLinkRepository(const MLExpr& expr)
	: key_(BAD_KEY)
	, repo_(NULL)
	, remoteName_(NULL)
	, committer_(NULL)
	, remote_(NULL)
	, connector_(NULL)
{
	MLExpr e = expr;
	if (e.testHead("GitObject") && e.length() == 2)
		e = e.part(2);
	if (e.testHead("GitRepo") && e.length() == 1)
		e = e.part(1);
	if (e.isInteger())
	{
		key_ = e.asMint();
		repo_ = ManagedRepoMap[key_];
	}
	else if (e.isString())
	{
		if (git_repository_open(&repo_, e.asString()) != 0)
		{
			git_repository_free(repo_);
			repo_ = NULL;
		}
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
	mint repoId = repoExpr.part(1).asInt();
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
	delete committer_;
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
	delete committer_;

	// recreating the signature every time assures correct commit times
	// and deals with the very rare cases where the repo's default committer changes
	committer_ = new Signature(*this);
	return *committer_;
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
	else if (git_remote_update_tips(remote_, committer(), "Wolfram GitLink: fetch"))
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

bool GitLinkRepository::setHead(const char* refName)
{
	git_reference* reference = NULL;
	errCode_ = errCodeParam_ = NULL;
	if (!isValid())
		errCode_ = Message::BadRepo;
	else if (git_reference_dwim(&reference, repo_, refName))
		errCode_ = Message::BadCommitish;
	else if (git_repository_set_head(repo_, git_reference_name(reference), committer(), "Wolfram GitLink: set HEAD"))
		errCode_ = Message::GitOperationFailed;

	if (reference != NULL)
		git_reference_free(reference);
	return errCode_ == NULL;
}

bool GitLinkRepository::checkoutHead(WolframLibraryData libData, MLExpr strategy, MLExpr notifyFlags)
{
	git_checkout_options opts;

	git_checkout_init_options(&opts, GIT_CHECKOUT_OPTIONS_VERSION);

	if (strategy.contains("Safe"))
		opts.checkout_strategy |= GIT_CHECKOUT_SAFE;
	if (strategy.contains("SafeCreate"))
		opts.checkout_strategy |= GIT_CHECKOUT_SAFE_CREATE;
	if (strategy.contains("Force"))
		opts.checkout_strategy |= GIT_CHECKOUT_FORCE;
	if (strategy.contains("AllowConflicts"))
		opts.checkout_strategy |= GIT_CHECKOUT_ALLOW_CONFLICTS;
	if (strategy.contains("RemoveUntracked"))
		opts.checkout_strategy |= GIT_CHECKOUT_REMOVE_UNTRACKED;
	if (strategy.contains("RemoveIgnored"))
		opts.checkout_strategy |= GIT_CHECKOUT_REMOVE_IGNORED;
	if (strategy.contains("UpdateOnly"))
		opts.checkout_strategy |= GIT_CHECKOUT_UPDATE_ONLY;
	if (strategy.contains("DontUpdateIndex"))
		opts.checkout_strategy |= GIT_CHECKOUT_DONT_UPDATE_INDEX;
	if (strategy.contains("NoRefresh"))
		opts.checkout_strategy |= GIT_CHECKOUT_NO_REFRESH;
	if (strategy.contains("SkipUnmerged"))
		opts.checkout_strategy |= GIT_CHECKOUT_SKIP_UNMERGED;
	if (strategy.contains("UseOurs"))
		opts.checkout_strategy |= GIT_CHECKOUT_USE_OURS;
	if (strategy.contains("UseTheirs"))
		opts.checkout_strategy |= GIT_CHECKOUT_USE_THEIRS;
	if (strategy.contains("DisablePathspecMatch"))
		opts.checkout_strategy |= GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH;
	if (strategy.contains("SkipLockedDirectories"))
		opts.checkout_strategy |= GIT_CHECKOUT_SKIP_LOCKED_DIRECTORIES;
	if (strategy.contains("DontOverwriteIgnored"))
		opts.checkout_strategy |= GIT_CHECKOUT_DONT_OVERWRITE_IGNORED;
	if (strategy.contains("ConflictStyleMerge"))
		opts.checkout_strategy |= GIT_CHECKOUT_CONFLICT_STYLE_MERGE;
	if (strategy.contains("ConflictStyleDiff3"))
		opts.checkout_strategy |= GIT_CHECKOUT_CONFLICT_STYLE_DIFF3;
	if (strategy.contains("UpdateSubmodules"))
		opts.checkout_strategy |= GIT_CHECKOUT_UPDATE_SUBMODULES;
	if (strategy.contains("UpdateSubmodulesIfChanged"))
		opts.checkout_strategy |= GIT_CHECKOUT_UPDATE_SUBMODULES_IF_CHANGED;

	if (notifyFlags.containsKey("Conflict"))
		opts.notify_flags |= GIT_CHECKOUT_NOTIFY_CONFLICT;
	if (notifyFlags.containsKey("Dirty"))
		opts.notify_flags |= GIT_CHECKOUT_NOTIFY_DIRTY;
	if (notifyFlags.containsKey("Updated"))
		opts.notify_flags |= GIT_CHECKOUT_NOTIFY_UPDATED;
	if (notifyFlags.containsKey("Untracked"))
		opts.notify_flags |= GIT_CHECKOUT_NOTIFY_UNTRACKED;
	if (notifyFlags.containsKey("Ignored"))
		opts.notify_flags |= GIT_CHECKOUT_NOTIFY_IGNORED;
	if (notifyFlags.containsKey("All"))
		opts.notify_flags |= GIT_CHECKOUT_NOTIFY_ALL;

	if (!git_checkout_head(repo_, &opts))
		return true;

	errCode_ = Message::CheckoutFailed;
	return false;
}


void GitLinkRepository::writeProperties(MLINK lnk) const
{
	if (isValid())
	{
		MLHelper helper(lnk);
		git_reference* headReference = NULL;

		git_repository_head(&headReference, repo_);

		helper.beginFunction("Association");
		if (headReference != NULL)
		{
			const char* branchName;
			helper.putRule("HEAD", git_reference_name(headReference));
			if (!git_branch_name(&branchName, headReference))
				helper.putRule("HeadBranch", branchName);
			git_reference_free(headReference);
		}
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
		writeRemotes(helper);

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

void GitLinkRepository::writeRemotes(MLHelper& helper) const
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

git_tree* GitLinkRepository::copyTree(MLExpr& expr)
{
	git_tree* returnValue = NULL;
	git_oid treeSha;
	bool treeShaFilled = false;

	if (expr.testSymbol("None"))
	{
		git_index* index = NULL;
		if (git_repository_index(&index, repo_) || git_index_write_tree_to(&treeSha, index, repo_))
			errCode_ = Message::NoIndex;
		else
			treeShaFilled = true;
		if (index)
			git_index_free(index);
	}
	else if (expr.isString())
	{
		if (git_oid_fromstr(&treeSha, expr.asString()))
			errCode_ = Message::BadSHA;
		else
			treeShaFilled = true;
	}

	if (treeShaFilled)
	{
		if (git_object_lookup((git_object**) &returnValue, repo_, &treeSha, GIT_OBJ_TREE))
			errCode_ = Message::NoTree;
	}
	return returnValue;
}
