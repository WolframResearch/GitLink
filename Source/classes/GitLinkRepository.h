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
 
const mint BAD_KEY = -1;

class GitLinkRepository : public GitLinkSuperClass
{
public:
	GitLinkRepository(WolframLibraryData libData, mint Argc, MArgument* Argv, int repoArg = 0);
	GitLinkRepository(mint key);
	GitLinkRepository(MLINK link);
	~GitLinkRepository();

	bool isValid() const { return repo_ != NULL; };

	mint key() const { return key_; };
	void setKey(mint key);
	void unsetKey();

	git_repository* repo() const { return repo_; };

	/// recreates the signature every time...but the signature is mutable in this class
	const git_signature* committer() const;

	bool fetch(const char* remoteName, const char* privateKeyFile, bool prune);

	bool push(MLINK lnk, const char* remoteName, const char* privateKeyFile, const char* branch);

	void writeProperties(MLINK lnk) const;

	void writeStatus(MLINK lnk) const;

	const char* privateKeyFile() const { return privateKeyFile_; };

private:
	git_repository* repo_;
	mutable git_signature* committer_;
	mint key_;
	char* remoteName_;
	git_remote* remote_;
	char* privateKeyFile_;

	bool setRemote_(const char* remoteName, const char* privateKeyFile);
	void writeConflictList_(MLHelper& helper) const;
	void writeRemoteList_(MLHelper& helper) const;
	void writeBranchList_(MLHelper& helper, git_branch_t flag) const;


	static int pushCallBack_(const char* ref, const char* msg, void* data);
	static int AcquireCredsCallBack(git_cred** cred,const char* url,const char *username,unsigned int allowed_types, void* payload);

};
#endif // GitLinkRepository_h_
