/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#ifndef GitLinkRepository_h_
#define GitLinkRepository_h_ 1

#include "MLHelper.h"
 
const mint BAD_KEY = -1;

class GitLinkRepository
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

	const char* fetch(const char* remoteName, const char* privateKeyFile, bool prune);

	const char* push(const char* remoteName, const char* branchName);

	void writeProperties(MLINK lnk) const;

	void writeStatus(MLINK lnk) const;

	const char* privateKeyFile() const { return privateKeyFile_; };

private:
	git_repository* repo_;
	mint key_;
	char* remoteName_;
	git_remote* remote_;
	char* privateKeyFile_;

	bool setRemote_(const char* remoteName, const char* privateKeyFile);
	void writeConflictList_(MLHelper& helper) const;
	void writeRemoteList_(MLHelper& helper) const;
	void writeBranchList_(MLHelper& helper, git_branch_t flag) const;
};
#endif // GitLinkRepository_h_
