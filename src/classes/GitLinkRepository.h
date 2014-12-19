/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#ifndef GitLinkRepository_h_
#define GitLinkRepository_h_ 1

#include "GitLinkSuperClass.h"
#include "RemoteConnector.h"
#include "MLExpr.h"
 
const mint BAD_KEY = -1;

class Signature;

class GitLinkRepository : public GitLinkSuperClass
{
public:
	GitLinkRepository(mint key);
	GitLinkRepository(MLINK link);
	GitLinkRepository(const MLExpr& expr);

	/// For newly created git_repositories which don't have don't have
	/// an in-kernel instance, yet
	GitLinkRepository(git_repository* repo, WolframLibraryData libData);

	~GitLinkRepository();



	bool isValid() const { return repo_ != NULL; };

	mint key() const { return key_; };
	void setKey(mint key);
	void unsetKey();

	git_repository* repo() const { return repo_; };

	/// Recreates the signature every time...but the signature is mutable in this class
	/// Note that you *must* NULL-check this, as it can fail
	const git_signature* committer() const;

	bool fetch(const char* remoteName, const char* privateKeyFile, bool prune);

	bool push(MLINK lnk, const char* remoteName, const char* privateKeyFile, const char* branch);

	void writeProperties(MLINK lnk) const;

	void writeStatus(MLINK lnk) const;

	git_tree* copyTree(MLExpr& expr);

	static int AcquireCredsCallBack(git_cred** cred,const char* url,const char *username,unsigned int allowed_types, void* payload);

private:
	RemoteConnector connector_;
	git_repository* repo_;
	mutable Signature* committer_;
	mint key_;
	char* remoteName_;
	git_remote* remote_;

	GitLinkRepository(const GitLinkRepository& repo) { };

	bool setRemote_(const char* remoteName, const char* privateKeyFile);
	bool connectRemote_(git_direction direction);
	void writeConflictList_(MLHelper& helper) const;
	void writeRemoteList_(MLHelper& helper) const;
	void writeBranchList_(MLHelper& helper, git_branch_t flag) const;


	static int pushCallBack_(const char* ref, const char* msg, void* data);

};

#endif // GitLinkRepository_h_
